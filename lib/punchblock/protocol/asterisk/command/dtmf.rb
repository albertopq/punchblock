          # Simulates pressing the specified digits over the current channel. Can be used to
          # traverse a phone menu.
          def dtmf(digits)
            execute "SendDTMF", digits.to_s
          end