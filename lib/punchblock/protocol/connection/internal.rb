require 'eventmachine'

module Punchblock
  class Protocol
    module Connection
      class Internal < GenericConnection
        extend ActiveSupport::Autoload

        attr_accessor :translator, :write_queue

        def initialize(options = {})
          super
          @translator = options[:translator]
          @write_queue = Queue.new
        end

        ##
        # Fire up the connection
        #
        def run
          translator.run
        end

        def event_queue
          translator.event_queue
        end

        def write(cmd, call_id, command_id = nil)
          queue = async_write cmd, call_id, command_id
          begin
            Timeout::timeout(3) { queue.pop }
          ensure
            queue = nil # Shut down this queue
          end.tap { |result| raise result if result.is_a? Exception }
        end

        ##
        # @return [Queue] Pop this queue to determine result of command execution. Will be true or an exception
        def async_write(cmd, call_id, command_id = nil)
          cmd.connection = self
          call_id = call_id.call_id unless call_id.is_a? String
          cmd.call_id = call_id

          Queue.new.tap do |queue|
            cmd.request!
            translator.write cmd do |result|
              case result
              when true, OzoneNode
                if result.is_a?(Ref)
                  cmd.command_id = result.id
                end
                cmd.execute!
                queue << true
              when Exception
                queue << result
              end
            end
          end
        end
      end
    end
  end
end
