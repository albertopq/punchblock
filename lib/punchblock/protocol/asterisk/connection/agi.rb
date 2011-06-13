module Punchblock
  module Protocol
    module Asterisk
      class Connection
        class AGI

          RESPONSE_PREFIX = "200 result=" unless defined? RESPONSE_PREFIX

          # These are the status messages that asterisk will issue after a dial command is executed.
          #
          # Here is a current list of dial status messages which are not all necessarily supported by adhearsion:
          #
          # ANSWER: Call is answered. A successful dial. The caller reached the callee.
          # BUSY: Busy signal. The dial command reached its number but the number is busy.
          # NOANSWER: No answer. The dial command reached its number, the number rang for too long, then the dial timed out.
          # CANCEL: Call is cancelled. The dial command reached its number but the caller hung up before the callee picked up.
          # CONGESTION: Congestion. This status is usually a sign that the dialled number is not recognised.
          # CHANUNAVAIL: Channel unavailable. On SIP, peer may not be registered.
          # DONTCALL: Privacy mode, callee rejected the call
          # TORTURE: Privacy mode, callee chose to send caller to torture menu
          # INVALIDARGS: Error parsing Dial command arguments (added for Asterisk 1.4.1, SVN r53135-53136)
          #
          # @see http://www.voip-info.org/wiki/index.php?page=Asterisk+variable+DIALSTATUS Asterisk Variable DIALSTATUS
          DIAL_STATUSES = Hash.new(:unknown).merge(:answer      => :answered, #:doc:
                                                   :congestion  => :congested,
                                                   :busy        => :busy,
                                                   :cancel      => :cancelled,
                                                   :noanswer    => :unanswered,
                                                   :cancelled   => :cancelled,
                                                   :chanunavail => :channel_unavailable) unless defined? DIAL_STATUSES

          DYNAMIC_FEATURE_EXTENSIONS = {
            :attended_transfer => lambda do |options|
              variable "TRANSFER_CONTEXT" => options[:context] if options && options.has_key?(:context)
              extend_dynamic_features_with "atxfer"
            end,
            :blind_transfer => lambda do |options|
              variable "TRANSFER_CONTEXT" => options[:context] if options && options.has_key?(:context)
              extend_dynamic_features_with 'blindxfer'
            end
          } unless defined? DYNAMIC_FEATURE_EXTENSIONS

          # Utility method to read from pbx. Hangup if nil.
          def read
            from_pbx.gets.tap do |message|
              # AGI has many conditions that might indicate a hangup
              raise Hangup if message.nil?

              ahn_log.agi.debug "<<< #{message}"

              code, rest = *message.split(' ', 2)

              case code.to_i
              when 510
                # This error is non-fatal for the call
                ahn_log.agi.warn "510: Invalid or unknown AGI command"
              when 511
                # 511 Command Not Permitted on a dead channel
                ahn_log.agi.debug "511: Dead channel. Raising Hangup"
                raise Hangup
              when 520
                # This error is non-fatal for the call
                ahn_log.agi.warn "520: Invalid command syntax"
              when (500..599)
                # Assume this error is non-fatal for the call and try to keep running
                ahn_log.agi.warn "#{code}: Unknown AGI protocol error."
              end

              # If the message starts with HANGUP it's a silly 1.6 OOB message
              case message
              when /^HANGUP/, /^HANGUP\n?$/i, /^HANGUP\s?\d{3}/i
                ahn_log.agi.debug "AGI HANGUP. Raising hangup"
                raise Hangup
              end
            end
          end

          # The underlying method executed by nearly all the command methods in this module.
          # Used to send the plaintext commands in the proper AGI format over TCP/IP back to an Asterisk server via the
          # FAGI protocol.
          #
          # It is not recommended that you call this method directly unless you plan to write a new command method
          # in which case use this to communicate directly with an Asterisk server via the FAGI protocol.
          #
          # @param [String] message
          #
          # @see http://www.voip-info.org/wiki/view/Asterisk+FastAGI More information about FastAGI
          def raw_response(message = nil)
            @call.with_command_lock do
              raise ArgumentError.new("illegal NUL in message #{message.inspect}") if message =~ /\0/
              ahn_log.agi.debug ">>> #{message}"
              write message if message
              read
            end
          end

          def response(command, *arguments)
            # Arguments surrounded by quotes; quotes backslash-escaped.
            # See parse_args in asterisk/res/res_agi.c (Asterisk 1.4.21.1)
            quote_arg = lambda { |arg|
              '"' + arg.gsub(/["\\]/) { |m| "\\#{m}" } + '"'
            }
            if arguments.empty?
              raw_response("#{command}")
            else
              raw_response("#{command} " + arguments.map{ |arg| quote_arg.call(arg.to_s) }.join(' '))
            end
          end

          protected

            # wait_for_digits waits for the input of digits based on the number of milliseconds
            def wait_for_digit(timeout = -1)
              timeout *= 1_000 if timeout != -1
              result = result_digit_from response("WAIT FOR DIGIT", timeout.to_i)
              (result == 0.chr) ? nil : result
            end

            # allows setting of the callerid number of the call
            def set_caller_id_number(caller_id_num)
              return unless caller_id_num
              raise ArgumentError, "Caller ID must be numeric" if caller_id_num.to_s !~ /^\d+$/
              variable "CALLERID(num)" => caller_id_num
            end

            # allows the setting of the callerid name of the call
            def set_caller_id_name(caller_id_name)
              return unless caller_id_name
              variable "CALLERID(name)" => caller_id_name
            end

            def timeout_from_dial_options(options)
              options[:for] || options[:timeout]
            end

            def dial_macro_option_compiler(confirm_argument_value)
              defaults = { :macro => 'ahn_dial_confirmer',
                           :timeout => 20.seconds,
                           :play => "beep",
                           :key => '#' }

              case confirm_argument_value
                when true
                  DialPlan::ConfirmationManager.encode_hash_for_dial_macro_argument(defaults)
                when false, nil
                  ''
                when Proc
                  raise NotImplementedError, "Coming in the future, you can do :confirm => my_context."
                when Hash
                  options = defaults.merge confirm_argument_value
                  if((confirm_argument_value.keys - defaults.keys).any?)
                    raise ArgumentError, "Known options: #{defaults.keys.to_sentence}"
                  end
                  raise ArgumentError, "Bad macro name!" unless options[:macro].to_s =~ /^[\w_]+$/
                  options[:timeout] = case options[:timeout]
                    when Fixnum, ActiveSupport::Duration
                      options[:timeout]
                    when String
                      raise ArgumentError, "Timeout must be numerical!" unless options[:timeout] =~ /^\d+$/
                      options[:timeout].to_i
                    when :none
                      0
                    else
                      raise ArgumentError, "Unrecognized :timeout! #{options[:timeout].inspect}"
                  end
                  raise ArgumentError, "Unrecognized DTMF key: #{options[:key]}" unless options[:key].to_s =~ /^[\d#*]$/
                  options[:play] = Array(options[:play]).join('++')
                  DialPlan::ConfirmationManager.encode_hash_for_dial_macro_argument options

                else
                  raise ArgumentError, "Unrecognized :confirm option: #{confirm_argument_value.inspect}!"
              end
            end

            def result_digit_from(response_string)
              raise ArgumentError, "Can't coerce nil into AGI response! This could be a bug!" unless response_string
              digit = response_string[/^#{response_prefix}(-?\d+(\.\d+)?)/,1]
              digit.to_i.chr if digit && digit.to_s != "-1"
            end

            def extract_input_from(result)
              return false if error?(result)
              # return false if input_timed_out?(result)

              # This regexp doesn't match if there was a timeout with no
              # inputted digits, therefore returning nil.

              result[/^#{response_prefix}([\d*]+)/, 1]
            end

            def play_sound_files_for_menu(menu_instance, sound_files)
              digit = nil
              if sound_files.any? && menu_instance.digit_buffer_empty?
                digit = interruptible_play(*sound_files)
              end
              digit || wait_for_digit(menu_instance.timeout)
            end

            def extend_dynamic_features_with(feature_name)
              current_variable = variable("DYNAMIC_FEATURES") || ''
              enabled_features = current_variable.split '#'
              unless enabled_features.include? feature_name
                enabled_features << feature_name
                variable "DYNAMIC_FEATURES" => enabled_features.join('#')
              end
            end

            def jump_to_context_with_name(context_name)
              context_lambda = lookup_context_with_name context_name
              raise Adhearsion::VoIP::DSL::Dialplan::ControlPassingException.new(context_lambda)
            end

            def lookup_context_with_name(context_name)
              begin
                send context_name
              rescue NameError
                raise Adhearsion::VoIP::DSL::Dialplan::ContextNotFoundException
              end
            end

            def redefine_extension_to_be(new_extension)
              new_extension = Adhearsion::VoIP::DSL::PhoneNumber.new new_extension
              meta_def(:extension) { new_extension }
            end

            def validate_digits(digits)
              digits.to_s.tap do |digits_as_string|
                raise ArgumentError, "Can only be called with valid digits!" unless digits_as_string =~ /^[0-9*#-]+$/
              end
            end

            def error?(result)
              result.to_s[/^#{response_prefix}(?:-\d+)/]
            end

            # timeout with pressed digits:    200 result=<digits> (timeout)
            # timeout without pressed digits: 200 result= (timeout)
            # @see http://www.voip-info.org/wiki/view/get+data AGI Get Data
            def input_timed_out?(result)
              result.starts_with?(response_prefix) && result.ends_with?('(timeout)')
            end

            module MenuDigitResponse
              def timed_out?
                eql? 0.chr
              end
            end

            module SpeechEngines
              class InvalidSpeechEngine < StandardError; end

              class << self
                def cepstral(text)
                  puts "in ceptral"
                  puts escape(text)
                end

                def festival(text)
                  raise NotImplementedError
                end

                def none(text)
                  raise InvalidSpeechEngine, "No speech engine selected. You must specify one in your Adhearsion config file."
                end

                def method_missing(engine_name, text)
                  raise InvalidSpeechEngine, "Unsupported speech engine #{engine_name} for speaking '#{text}'"
                end

                private

                def escape(text)
                  "%p" % text
                end
              end
            end # SpeechEngines
        end # AGI
      end # Connection
    end # Asterisk
  end # Protocol
end # Punchblock
