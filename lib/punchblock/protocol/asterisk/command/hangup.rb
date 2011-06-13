          # Hangs up the current channel. After this command is issued, you will not be able to send any more AGI
          # commands but the dialplan Thread will still continue, allowing you to do any post-call work.
          #
          def hangup
            response 'HANGUP'
          end