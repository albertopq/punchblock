module Punchblock
  module Protocol
    module Asterisk
      module Command
        class Say
          def self.new(options = {})
            # Sketch:
            # * Check for a URL
            # * If URL, check for URL to have file: protocol
            # * If File URL, strip file:// prefix and pass to Asterisk
            # * If Other URL, exec a CURL or System command to get file into a temp area on Asterisk box
            # * - Then pass temp path to Asterisk
            # * - Then cleanup when complete playing
            # * Else Not URL, figure out what Type we are speaking (text, time, date, numeric string, ???)
            # * If Text, figure out TTS
            # * Engage TTS if available
          end
        end # Answer
      end # Command
    end # Asterisk
  end # Protocol
end # Punchblock

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