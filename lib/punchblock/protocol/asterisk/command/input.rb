          # Used to receive keypad input from the user. Digits are collected
          # via DTMF (keypad) input until one of three things happens:
          #
          #  1. The number of digits you specify as the first argument is collected
          #  2. The timeout you specify with the :timeout option elapses.
          #  3. The "#" key (or the key you specify with :accept_key) is pressed
          #
          # Usage examples
          #
          #   input   # Receives digits until the caller presses the "#" key
          #   input 3 # Receives three digits. Can be 0-9, * or #
          #   input 5, :accept_key => "*"   # Receive at most 5 digits, stopping if '*' is pressed
          #   input 1, :timeout => 1.minute # Receive a single digit, returning an empty
          #                                   string if the timeout is encountered
          #   input 9, :timeout => 7, :accept_key => "0" # Receives nine digits, returning
          #                                              # when the timeout is encountered
          #                                              # or when the "0" key is pressed.
          #   input 3, :play => "you-sound-cute"
          #   input :play => ["if-this-is-correct-press", 1, "otherwise-press", 2]
          #
          # When specifying files to play, the playback of the sequence of files will stop
          # immediately when the user presses the first digit.
          #
          # The :timeout option works like a digit timeout, therefore each digit pressed
          # causes the timer to reset. This is a much more user-friendly approach than an
          # absolute timeout.
          #
          # Note that when the digit limit is not specified the :accept_key becomes "#".
          # Otherwise there would be no way to end the collection of digits. You can
          # obviously override this by passing in a new key with :accept_key.
          def input(*args)
            options = args.last.kind_of?(Hash) ? args.pop : {}
            number_of_digits = args.shift

            sound_files     = Array options.delete(:play)
            timeout         = options.delete(:timeout)
            terminating_key = options.delete(:accept_key)
            terminating_key = if terminating_key
              terminating_key.to_s
            elsif number_of_digits.nil? && !terminating_key.equal?(false)
              '#'
            end

            if number_of_digits && number_of_digits < 0
              ahn_log.agi.warn "Giving -1 to input() is now deprecated. Don't specify a first " +
                               "argument to simulate unlimited digits." if number_of_digits == -1
              raise ArgumentError, "The number of digits must be positive!"
            end

            buffer = ''
            key = sound_files.any? ? interruptible_play(*sound_files) || '' : wait_for_digit(timeout || -1)
            loop do
              return buffer if key.nil?
              if terminating_key
                if key == terminating_key
                  return buffer
                else
                  buffer << key
                  return buffer if number_of_digits && number_of_digits == buffer.length
                end
              else
                buffer << key
                return buffer if number_of_digits && number_of_digits == buffer.length
              end
              key = wait_for_digit(timeout || -1)
            end
          end