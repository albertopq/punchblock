# Dial an extension or "phone number" in asterisk.
# Maps to the Asterisk DIAL command in the asterisk dialplan.
#
# @param [String] number represents the extension or "number" that asterisk should dial.
# Be careful to not just specify a number like 5001, 9095551001
# You must specify a properly formatted string as Asterisk would expect to use in order to understand
# whether the call should be dialed using SIP, IAX, or some other means.
#
# @param [Hash] options
#
# +:caller_id+ - the caller id number to be used when the call is placed.  It is advised you properly adhere to the
# policy of VoIP termination providers with respect to caller id values.
#
# +:name+ - this is the name which should be passed with the caller ID information
# if :name=>"John Doe" and :caller_id => "444-333-1000" then the compelete CID and name would be "John Doe" <4443331000>
# support for caller id information varies from country to country and from one VoIP termination provider to another.
#
# +:for+ - this option can be thought of best as a timeout.  i.e. timeout after :for if no one answers the call
# For example, dial("SIP/jay-desk-650&SIP/jay-desk-601&SIP/jay-desk-601-2", :for => 15.seconds, :caller_id => callerid)
# this call will timeout after 15 seconds if 1 of the 3 extensions being dialed do not pick prior to the 15 second time limit
#
# +:options+ - This is a string of options like "Tr" which are supported by the asterisk DIAL application.
# for a complete list of these options and their usage please check the link below.
#
# +:confirm+ - ?
#
# @example Make a call to the PSTN using my SIP provider for VoIP termination
#   dial("SIP/19095551001@my.sip.voip.terminator.us")
#
# @example Make 3 Simulataneous calls to the SIP extensions separated by & symbols, try for 15 seconds and use the callerid
# for this call specified by the variable my_callerid
#   dial "SIP/jay-desk-650&SIP/jay-desk-601&SIP/jay-desk-601-2", :for => 15.seconds, :caller_id => my_callerid
#
# @example Make a call using the IAX provider to the PSTN
#   dial("IAX2/my.id@voipjet/19095551234", :name=>"John Doe", :caller_id=>"9095551234")
#
# @see http://www.voip-info.org/wiki-Asterisk+cmd+Dial Asterisk Dial Command
def dial(number, options={})
  *recognized_options = :caller_id, :name, :for, :options, :confirm

  unrecognized_options = options.keys - recognized_options
  raise ArgumentError, "Unknown dial options: #{unrecognized_options.to_sentence}" if unrecognized_options.any?
  set_caller_id_name options[:name]
  set_caller_id_number options[:caller_id]
  confirm_option = dial_macro_option_compiler options[:confirm]
  all_options = options[:options]
  all_options = all_options ? all_options + confirm_option : confirm_option
  execute "Dial", number, options[:for], all_options
end

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