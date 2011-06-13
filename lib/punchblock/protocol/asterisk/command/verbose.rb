          # Sends a message to the console via the verbose message system.
          #
          # @param [String] message
          # @param [Integer] level
          #
          # @return the result of the command
          #
          # @example Use this command to inform someone watching the Asterisk console
          # of actions happening within Adhearsion.
          #   verbose 'Processing call with Adhearsion' 3
          #
          # @see http://www.voip-info.org/wiki/view/verbose
          def verbose(message, level = nil)
              result = raw_response("VERBOSE \"#{message}\" #{level}")
              return false if error?(result)
              result
          end