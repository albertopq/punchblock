          # Plays the specified sound file names. This method will handle Time/DateTime objects (e.g. Time.now),
          # Fixnums (e.g. 1000), Strings which are valid Fixnums (e.g "123"), and direct sound files. When playing
          # numbers, Adhearsion assumes you're saying the number, not the digits. For example, play("100")
          # is pronounced as "one hundred" instead of "one zero zero". To specify how the Date/Time objects are said
          # pass in as an array with the first parameter as the Date/Time/DateTime object along with a hash with the
          # additional options.  See play_time for more information.
          #
          # Note: it is not necessary to supply a sound file extension; Asterisk will try to find a sound
          # file encoded using the current channel's codec, if one exists. If not, it will transcode from
          # the default codec (GSM). Asterisk stores its sound files in /var/lib/asterisk/sounds.
          #
          # @example Play file hello-world.???
          #   play 'hello-world'
          # @example Speak current time
          #   play Time.now
          # @example Speak today's date
          #   play Date.today
          # @example Speak today's date in a specific format
          #   play [Date.today, {:format => 'BdY'}]
          # @example Play sound file, speak number, play two more sound files
          #   play %w"a-connect-charge-of 22 cents-per-minute will-apply"
          # @example Play two sound files
          #   play "you-sound-cute", "what-are-you-wearing"
          #
          def play(*arguments)
            unless play_time(arguments)
              arguments.flatten.each do |argument|
                play_numeric(argument) || play_string(argument)
              end
            end
          end

          # Play a sequence of files, stopping the playback if a digit is pressed.
          #
          # @return [String, nil] digit pressed, or nil if none
          #
          def interruptible_play(*files)
            files.flatten.each do |file|
              result = result_digit_from response("STREAM FILE", file, "1234567890*#")
              return result if result != 0.chr
            end
            nil
          end

          # Plays the given Date, Time, or Integer (seconds since epoch)
          # using the given timezone and format.
          #
          # @param [Date|Time|DateTime] Time to be said.
          # @param [Hash] Additional options to specify how exactly to say time specified.
          #
          # +:timezone+ - Sends a timezone to asterisk. See /usr/share/zoneinfo for a list. Defaults to the machine timezone.
          # +:format+   - This is the format the time is to be said in.  Defaults to "ABdY 'digits/at' IMp"
          #
          # @see http://www.voip-info.org/wiki/view/Asterisk+cmd+SayUnixTime
          def play_time(*args)
            argument, options = args.flatten
            options ||= {}

            return false unless options.is_a? Hash

            timezone = options.delete(:timezone) || ''
            format   = options.delete(:format)   || ''
            epoch    = case argument
                       when Time || DateTime
                         argument.to_i
                       when Date
                         format = 'BdY' unless format.present?
                         argument.to_time.to_i
                       end

            return false if epoch.nil?

            execute :sayunixtime, epoch, timezone, format
          end

          protected

            def play_numeric(argument)
              if argument.kind_of?(Numeric) || argument =~ /^\d+$/
                execute(:saynumber, argument)
              end
            end

            def play_string(argument)
              execute(:playback, argument)
            end