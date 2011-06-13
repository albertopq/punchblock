          # Issue this command to access a channel variable that exists in the asterisk dialplan (i.e. extensions.conf)
          # Use get_variable to pass information from other modules or high level configurations from the asterisk dialplan
          # to the adhearsion dialplan.
          #
          # @param [String] variable_name
          #
          # @see: http://www.voip-info.org/wiki/view/get+variable Asterisk Get Variable
          def get_variable(variable_name)
            result = response("GET VARIABLE", variable_name)
            case result
              when "200 result=0"
                return nil
            when /^200 result=1 \((.*)\)$/
              return $LAST_PAREN_MATCH
            end
          end

          # Pass information back to the asterisk dial plan.
          #
          # Keep in mind that the variables are not global variables. These variables only exist for the channel
          # related to the call that is being serviced by the particular instance of your adhearsion application.
          # You will not be able to pass information back to the asterisk dialplan for other instances of your adhearsion
          # application to share. Once the channel is "hungup" then the variables are cleared and their information is gone.
          #
          # @param [String] variable_name
          # @param [String] value
          #
          # @see http://www.voip-info.org/wiki/view/set+variable Asterisk Set Variable
          def set_variable(variable_name, value)
            response("SET VARIABLE", variable_name, value) == "200 result=1"
          end

          # Allows you to either set or get a channel variable from Asterisk.
          # The method takes a hash key/value pair if you would like to set a variable
          # Or a single string with the variable to get from Asterisk
          def variable(*args)
            if args.last.kind_of? Hash
              assignments = args.pop
              raise ArgumentError, "Can't mix variable setting and fetching!" if args.any?
              assignments.each_pair do |key, value|
                set_variable(key, value)
              end
            else
              if args.size == 1
                get_variable args.first
              else
                args.map { |var| get_variable(var) }
              end
            end
          end

          # FIXME: Where do these methods belong?
          # Issue the command to add a custom SIP header to the current call channel
          # example use: sip_add_header("x-ahn-test", "rubyrox")
          #
          # @param[String] the name of the SIP header
          # @param[String] the value of the SIP header
          #
          # @return [String] the Asterisk response
          #
          # @see http://www.voip-info.org/wiki/index.php?page=Asterisk+cmd+SIPAddHeader Asterisk SIPAddHeader
          def sip_add_header(header, value)
            execute("SIPAddHeader", "#{header}: #{value}") == "200 result=1"
          end

          # Issue the command to fetch a SIP header from the current call channel
          # example use: sip_get_header("x-ahn-test")
          #
          # @param[String] the name of the SIP header to get
          #
          # @return [String] the Asterisk response
          #
          # @see http://www.voip-info.org/wiki/index.php?page=Asterisk+cmd+SIPGetHeader Asterisk SIPGetHeader
          def sip_get_header(header)
            get_variable("SIP_HEADER(#{header})")
          end
          alias :sip_header :sip_get_header


          protected

            def extract_variable_from(result)
              return false if error?(result)
              result[/^#{response_prefix}1 \((.+)\)/, 1]
            end