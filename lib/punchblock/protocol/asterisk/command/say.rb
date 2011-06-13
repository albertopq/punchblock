          # This implementation of dial() uses the experimental call routing DSL.
          #
          # def dial(number, options={})
          #   rules = callable_routes_for number
          #   return :no_route if rules.empty?
          #   call_attempt_status = nil
          #   rules.each do |provider|
          #
          #     response = execute "Dial",
          #       provider.format_number_for_platform(number),
          #       timeout_from_dial_options(options),
          #       asterisk_options_from_dial_options(options)
          #
          #     call_attempt_status = last_dial_status
          #     break if call_attempt_status == :answered
          #   end
          #   call_attempt_status
          # end


          # Speaks the digits given as an argument. For example, "123" is spoken as "one two three".
          #
          # @param [String] digits
          def say_digits(digits)
            execute "saydigits", validate_digits(digits)
          end

          ##
          # Executes the SayPhonetic command. This command will read the text passed in
          # out load using the NATO phonetic alphabet.
          #
          # @param [String] Passed in as the text to read aloud
          #
          # @see http://www.voip-info.org/wiki/view/Asterisk+cmd+SayPhonetic Asterisk SayPhonetic Command
          def say_phonetic(text)
            execute "sayphonetic", text
          end

          ##
          # Executes the SayAlpha command. This command will read the text passed in
          # out loud, character-by-character.
          #
          # @param [String] Passed in as the text to read aloud
          #
          # @example Say "one a two dot pound"
          #   say_chars "1a2.#"
          #
          # @see http://www.voip-info.org/wiki/view/Asterisk+cmd+SayAlpha Asterisk SayPhonetic Command
          def say_chars(text)
            execute "sayalpha", text
          end