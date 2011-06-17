module Punchblock
  module Protocol
    module Asterisk
      module Command

        ##
        # An Asterisk Answer message.
        #
        # @example
        #    Answer.new.to_s
        #
        #    returns:
        #        ANSWER
        class Answer
          def to_s
            'ANSWER'
          end
        end # Answer
      end # Command
    end # Asterisk
  end # Protocol
end # Punchblock
