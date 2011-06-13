          # This asterisk dialplan command allows you to instruct Asterisk to start applications
          # which are typically run from extensions.conf.
          #
          # The most common commands are already made available through the FAGI interface provided
          # by this code base. For commands that do not fall into this category, then exec is what you
          # should use.
          #
          # For example, if there are specific asterisk modules you have loaded that will not be
          # available through the standard commands provided through FAGI - then you can used EXEC.
          #
          # @example Using execute in this way will add a header to an existing SIP call.
          #   execute 'SIPAddHeader', '"Call-Info: answer-after=0"
          #
          # @see http://www.voip-info.org/wiki/view/Asterisk+-+documentation+of+application+commands Asterisk Dialplan Commands
          def execute(application, *arguments)
            result = raw_response(%{EXEC %s "%s"} % [ application,
              arguments.join(%{"#{AHN_CONFIG.asterisk.argument_delimiter}"}) ])
            return false if error?(result)
            result
          end