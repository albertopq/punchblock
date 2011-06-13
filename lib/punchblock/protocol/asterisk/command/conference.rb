module Punchblock
  module Protocol
    module Asterisk
      module Command
        class Conference
          def self.new(room_id, options = {})
            conference_id = conference_id.to_s.scan(/\w/).join
            command_flags = options[:options].to_s # This is a passthrough string straight to Asterisk
            pin = options[:pin]
            raise ArgumentError, "A conference PIN number must be numerical!" if pin && pin.to_s !~ /^\d+$/

            # To disable dynamic conference creation set :use_static_conf => true
            use_static_conf = options.has_key?(:use_static_conf) ? options[:use_static_conf] : false

            # The 'd' option of MeetMe creates conferences dynamically.
            command_flags += 'd' unless (command_flags.include?('d') or use_static_conf)

            @msg = "MeetMe", conference_id, command_flags, options[:pin]
          end

          def to_s
            @msg
          end
        end # Conference
      end # Command
    end # Asterisk
  end # Protocol
end # Punchblock
