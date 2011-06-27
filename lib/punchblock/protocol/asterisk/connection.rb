%w{
timeout
blather/client/dsl
}.each { |f| require f }

module Punchblock
  module Protocol
    module Asterisk
      class Connection < GenericConnection
        extend ActiveSupport::Autoload
        autoload :AMI
        autoload :AGI
        
        DEFAULT_OPTIONS = {
          :agi => {
            :listening_addr => '::',
            :listening_port => 4573,
          },
          :ami => {
            :host => '::1',
            :port => 5038,
          },
        }

        attr_accessor :event_queue

        def initialize(options = {})
          super
          options[:ami] = DEFAULT_OPTIONS[:ami].merge options[:ami]
          options[:agi] = DEFAULT_OPTIONS[:agi].merge options[:agi]
          raise ArgumentError unless options.has_key? :ami
          raise ArgumentError unless options[:ami].has_key? :user
          raise ArgumentError unless options[:ami].has_key? :pass
          @ami = AMI.new options[:ami]
          @agi = AGI.new options[:agi]


          # This queue is used to synchronize between threads calling #write
          # and the connection-level responses they need to return from the
          # EventMachine loop.
          @result_queues = {}

          @callmap = {} # This hash maps call IDs to their XMPP domain.

          Blather.logger = options.delete(:wire_logger) if options.has_key?(:wire_logger)

          # Push a message to the queue and the log that we connected
          when_ready do
            @event_queue.push connected
            @logger.info "Connected to XMPP as #{@username}" if @logger
          end

          # Read/handle call control messages
          iq do |msg|
            read msg
          end

          # Force autoload events so they get registered properly
          [Event::Complete, Event::End, Event::Info, Event::Offer]

          # Read/handle presence requests. This is how new calls are set up.
          presence do |msg|
            @logger.info "Receiving event for call ID #{msg.call_id}"
            @callmap[msg.call_id] = msg.from.domain
            @logger.debug msg.inspect if @logger
            event = msg.event
            @event_queue.push event.is_a?(Event::Offer) ? Punchblock::Call.new(msg.call_id, msg.to, event.headers_hash) : event
          end
        end

        def read(iq)
          # FIXME: Do we need to raise a warning if the domain changes?
          @callmap[iq.from.node] = iq.from.domain
          case iq.type
          when :result
            # Send this result to the waiting queue
            @logger.debug "Command #{iq.id} completed successfully" if @logger
            @result_queues[iq.id].push iq
          when :error
            # TODO: Example messages to handle:
            #------
            #<iq type="error" id="blather0016" to="usera@127.0.0.1/voxeo" from="15dce14a-778e-42f2-9ac4-501805ec0388@127.0.0.1">
            #  <answer xmlns="urn:xmpp:ozone:1"/>
            #  <error type="cancel">
            #    <item-not-found xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>
            #  </error>
            #</iq>
            #------
            # FIXME: This should probably be parsed by the Protocol layer and return
            # a ProtocolError exception.
            if @result_queues.has_key?(iq.id)
              @result_queues[iq.id].push TransportError.new iq
            else
              # Un-associated transport error??
              raise TransportError, iq
            end
          else
            raise TransportError, iq
          end
        end

        def write(call, msg)
          if msg.is_a?(Command::Dial)
            jid = @client_jid.domain
            iq = create_iq jid
            @logger.debug "Sending IQ ID #{iq.id} #{msg.inspect} to #{jid}" if @logger
          else
            iq = create_iq "#{call.call_id}@#{@callmap[call.call_id]}"
            @logger.debug "Sending IQ ID #{iq.id} #{msg.inspect} to #{call.call_id}" if @logger
          end
          iq << msg
          @result_queues[iq.id] = Queue.new
          write_to_stream iq
          result = read_queue_with_timeout @result_queues[iq.id]
          @result_queues[iq.id] = nil # Shut down this queue
          # FIXME: Error handling
          raise result if result.is_a? Exception
          true
        end

        def create_iq(jid = nil)
          Blather::Stanza::Iq.new(:set, jid || @call_id).tap do |iq|
            iq.from = @client_jid
          end
        end

        def run
          EM.run { client.run }
        end

        def connected?
          client.connected?
        end

        private

        def read_queue_with_timeout(queue, timeout = 3)
          begin
            Timeout::timeout(timeout) { queue.pop }
          rescue Timeout::Error => e
            e.to_s
          end
        end
      end
    end
  end
end
