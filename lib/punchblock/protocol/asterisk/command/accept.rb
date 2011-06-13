module Punchblock
  module Protocol
    module Asterisk
      module Command
        ##
        # An Ozone accept message.  This is equivalent to a SIP "180 Trying"
        #
        # @example
        #    Accept.new.to_s
        #
        #    returns:
        #        EXECUTE Ringing
        class Accept
          def to_s
            
          end
        end # Accept
      end # Command
    end # Asterisk
  end # Protocol
end # Punchblock
