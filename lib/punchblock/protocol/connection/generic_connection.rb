module Punchblock
  class Protocol
    module Connection
      class GenericConnection
        attr_accessor :event_queue, :logger, :wire_logger

        ##
        # @param [Hash] options
        # @option options [Logger] :transport_logger The logger to which transport events will be logged
        #
        def initialize(options = {})
          @event_queue = Queue.new
          @logger = options.delete(:transport_logger) if options[:transport_logger]

          # FIXME: Force autoload events so they get registered properly
          [Event::Answered, Event::Complete, Event::End, Event::Info, Event::Offer, Event::Ringing, Ref]
        end

        def connected
          'CONNECTED'
        end
      end
    end
  end
end
