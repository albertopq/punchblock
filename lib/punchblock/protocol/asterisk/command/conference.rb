
          # Used to join a particular conference with the MeetMe application. To use MeetMe, be sure you
          # have a proper timing device configured on your Asterisk box. MeetMe is Asterisk's built-in
          # conferencing program.
          #
          # @param [String] conference_id
          # @param [Hash] options
          #
          # @see http://www.voip-info.org/wiki-Asterisk+cmd+MeetMe Asterisk Meetme Application Information
          def join(conference_id, options={})
            conference_id = conference_id.to_s.scan(/\w/).join
            command_flags = options[:options].to_s # This is a passthrough string straight to Asterisk
            pin = options[:pin]
            raise ArgumentError, "A conference PIN number must be numerical!" if pin && pin.to_s !~ /^\d+$/

            # To disable dynamic conference creation set :use_static_conf => true
            use_static_conf = options.has_key?(:use_static_conf) ? options[:use_static_conf] : false

            # The 'd' option of MeetMe creates conferences dynamically.
            command_flags += 'd' unless (command_flags.include?('d') or use_static_conf)

            execute "MeetMe", conference_id, command_flags, options[:pin]
          end