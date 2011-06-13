          # Send a caller to a voicemail box to leave a message.
          #
          # The method takes the mailbox_number of the user to leave a message for and a
          # greeting_option that will determine which message gets played to the caller.
          #
          # @see http://www.voip-info.org/tiki-index.php?page=Asterisk+cmd+VoiceMail Asterisk Voicemail
          def voicemail(*args)
            options_hash    = args.last.kind_of?(Hash) ? args.pop : {}
            mailbox_number  = args.shift
            greeting_option = options_hash.delete(:greeting)
            skip_option     = options_hash.delete(:skip)
            raise ArgumentError, 'You supplied too many arguments!' if mailbox_number && options_hash.any?
            greeting_option = case greeting_option
              when :busy then 'b'
              when :unavailable then 'u'
              when nil then nil
              else raise ArgumentError, "Unrecognized greeting #{greeting_option}"
            end
            skip_option &&= 's'
            options = "#{greeting_option}#{skip_option}"

            raise ArgumentError, "Mailbox cannot be blank!" if !mailbox_number.nil? && mailbox_number.blank?
            number_with_context = if mailbox_number then mailbox_number else
              raise ArgumentError, "You must supply ONE context name!" if options_hash.size != 1
              context_name, mailboxes = options_hash.to_a.first
              Array(mailboxes).map do |mailbox|
                raise ArgumentError, "Mailbox numbers must be numerical!" unless mailbox.to_s =~ /^\d+$/
                "#{mailbox}@#{context_name}"
              end.join('&')
            end
            execute('voicemail', number_with_context, options)
            case variable('VMSTATUS')
              when 'SUCCESS' then true
              when 'USEREXIT' then false
              else nil
            end
          end

          # The voicemail_main method puts a caller into the voicemail system to fetch their voicemail
          # or set options for their voicemail box.
          #
          # @param [Hash] options
          #
          # @see http://www.voip-info.org/wiki-Asterisk+cmd+VoiceMailMain Asterisk VoiceMailMain Command
          def voicemail_main(options={})
            mailbox, context, folder = options.values_at :mailbox, :context, :folder
            authenticate = options.has_key?(:authenticate) ? options[:authenticate] : true

            folder = if folder
              if folder.to_s =~ /^[\w_]+$/
                "a(#{folder})"
              else
                raise ArgumentError, "Voicemail folder must be alphanumerical/underscore characters only!"
              end
            elsif folder == ''
              raise "Folder name cannot be an empty String!"
            else
              nil
            end

            real_mailbox = ""
            real_mailbox << "#{mailbox}"  unless mailbox.blank?
            real_mailbox << "@#{context}" unless context.blank?

            real_options = ""
            real_options << "s" if !authenticate
            real_options << folder unless folder.blank?

            command_args = [real_mailbox]
            command_args << real_options unless real_options.blank?
            command_args.clear if command_args == [""]

            execute 'VoiceMailMain', *command_args
          end