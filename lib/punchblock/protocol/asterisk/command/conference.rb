module Punchblock
  module Protocol
    module Asterisk
      module Command

        ##
        # An Asterisk Conference message. This will join the call to a
        # conference.  Because Asterisk supports several possible conference
        # types (including the built-in MeetMe and ConfBridge, plus third party
        # implementations such as app_conference and app_konference) this class
        # can be configured to select the correct backend. If unspecified, the
        # default is MeetMe.
        #
        # @example
        #    Conference.new(1234).to_msg
        #
        #    returns:
        #        EXECUTE MeetMe 1234,d
        class Conference
          def initialize(conference_id, options = {})
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

          class MeetMe < Conference
            def to_msg
              "EXECUTE MeetMe #{format_args}"
            end

            def format_args
              args = @conference_id.to_s
              args << ',' # Delimit args
              args << 'a' if @options[:admin]
              args << 'A' if @options[:marked_user]
              args << 'd' if @options[:dynamic] #FIXME: Default to true
              args << 'c' if @options[:announce_count] #FIXME: Default to true?
              args << if @options[:dynamic] #FIXME: Default to true
                @options[:pin] ? 'D' : 'd'
              end
              args << 'e' if @options[:join_first_empty]
              args << 'E' if @options[:join_first_empty_noauth]
              args << 'F' if @options[:pass_dtmf]
              args << "G(#{@options[:announce_msg]})" if @options[:announce_msg]
              args << 'i' if @options[:announce_participant_changes_with_review]
              args << 'I' if @options[:announce_participant_changes]
              args << 'l' if @options[:listen_only]
              args << 'm' if @options[:join_muted]
              if @options[:moh_when_empty]
                args << 'M'
                args << "(#{@options[:moh_class]})" if @options[:moh_class]
              end
              args << 'o' if @options[:talker_optimization]
              if @options[:escape]
                args << 'p'
                args << "(#{@options[:escape_digits]})" if @options[:escape_digits]
              end
              args << 'P' if @options[:force_auth]
              args << 'q' if @options[:stealth]
              args << 'r' if @options[:record]
              # TODO Should also allow for setting channel variables
              # MEETME_RECORDINGFILE and MEETME_RECORDINGFORMAT
              args << 's' if @options[:enable_menu] #FIXME: Default to true?
              args << 't' if @options[:talk_only]
              args << 'T' if @options[:talker_events] #FIXME: Default to true
              args << 'w' if @options[:wait_for_marked_user]
              # TODO Allow for max duration param to 'w'
              args << 'x' if @options[:close_on_last_marked_user_exit]
              args << '1' if @options[:skip_announce_on_first_join]
              args << "S(#{@options[:max_duration]})" if @options[:max_duration]
              # TODO: Document that S() is in seconds
              # TODO: Implement the L() limit option and params
              args << ',' # Delimit args
              args << @options[:pin] if @options[:pin]
            end
          end

          class ConfBridge < Conference
            def to_msg
              "EXECUTE ConfBridge #{format_args}"
            end

            def format_args
              # FIXME: Do we want to check for unused options and warn if they
              # are not valid for this conference type?
              args = @conference_id.to_s
              args << ',' # Delimit args
              args << 'a' if @options[:admin]
              args << 'A' if @options[:marked_user]
              args << 'c' if @options[:announce_count]
              args << 'm' if @options[:join_muted]
              if @options[:moh_when_empty]
                args << 'M'
                args << "(#{@options[:moh_class]})" if @options[:moh_class]
              end
              args << '1' if @options[:skip_announce_on_first_join]
              args << 's' if @options[:enable_menu] #FIXME: Default to true?
              args << 'w' if @options[:wait_for_marked_user]
              args << 'q' if @options[:stealth]
            end

          end
        end # Conference
      end # Command
    end # Asterisk
  end # Protocol
end # Punchblock
