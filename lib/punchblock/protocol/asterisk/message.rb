module Punchblock
  class Protocol
    module Asterisk
      extend ActiveSupport::Autoload

      class Message
        attr_accessor :call_id

        RESPONSE_PREFIX = "200 result=" unless defined? RESPONSE_PREFIX

        # These are the status messages that asterisk will issue after a dial command is executed.
        #
        # Here is a current list of dial status messages which are not all necessarily supported by adhearsion:
        #
        # ANSWER: Call is answered. A successful dial. The caller reached the callee.
        # BUSY: Busy signal. The dial command reached its number but the number is busy.
        # NOANSWER: No answer. The dial command reached its number, the number rang for too long, then the dial timed out.
        # CANCEL: Call is cancelled. The dial command reached its number but the caller hung up before the callee picked up.
        # CONGESTION: Congestion. This status is usually a sign that the dialled number is not recognised.
        # CHANUNAVAIL: Channel unavailable. On SIP, peer may not be registered.
        # DONTCALL: Privacy mode, callee rejected the call
        # TORTURE: Privacy mode, callee chose to send caller to torture menu
        # INVALIDARGS: Error parsing Dial command arguments (added for Asterisk 1.4.1, SVN r53135-53136)
        #
        # @see http://www.voip-info.org/wiki/index.php?page=Asterisk+variable+DIALSTATUS Asterisk Variable DIALSTATUS
        DIAL_STATUSES = Hash.new(:unknown).merge(:answer      => :answered, #:doc:
                                                 :congestion  => :congested,
                                                 :busy        => :busy,
                                                 :cancel      => :cancelled,
                                                 :noanswer    => :unanswered,
                                                 :cancelled   => :cancelled,
                                                 :chanunavail => :channel_unavailable) unless defined? DIAL_STATUSES

        ##
        # Create a new Asterisk AGI or AMI Message object.
        #
        def initialize(name, options = {})
          @name, @options = name, options
        end

        # @param [String] Call ID
        # @param [String] Call Command ID. Can be nil
        # @param [String] String to be converted to an AGI or AMI Message
        def self.parse(call_id, cmd_id, msg)
        end
      end # Message
    end # Asterisk
  end # Protocol
end # Punchblock
