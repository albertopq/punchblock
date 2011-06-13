require 'nokogiri'

module Punchblock
  module Protocol
    module Asterisk
      extend ActiveSupport::Autoload

      autoload :Command
      
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
        DIAL_STATUSES   = Hash.new(:unknown).merge(:answer      => :answered, #:doc:
                                                   :congestion  => :congested,
                                                   :busy        => :busy,
                                                   :cancel      => :cancelled,
                                                   :noanswer    => :unanswered,
                                                   :cancelled   => :cancelled,
                                                   :chanunavail => :channel_unavailable) unless defined? DIAL_STATUSES

        ##
        # Create a new Asterisk AGI or AMI Message object.
        #
        # @param [Symbol, Required] Component for this new message
        # @param [Nokogiri::XML::Document, Optional] Existing XML document to which this message should be added
        #
        # @return [Ozone::Message] New Ozone Message object
        def initialize(name, options = {})
          @name, @options = name, options
        end

        # @param [String] Call ID
        # @param [String] Call Command ID.  Can be nil
        # @param [String] String to be converted to an AGI or AMI Message
        def self.parse(call_id, cmd_id, msg)
        end
      end

      ##
      # An Ozone answer message.  This is equivalent to a SIP "200 OK"
      #
      # @example
      #    Answer.new.to_xml
      #
      #    returns:
      #        <answer xmlns="urn:xmpp:ozone:1"/>
      class Answer < Message
        def to_s
          'ANSWER'
        end
      end

      ##
      # An Ozone hangup message
      #
      # @example
      #    Hangup.new.to_xml
      #
      #    returns:
      #        <hangup xmlns="urn:xmpp:ozone:1"/>
      class Hangup < Message
        def to_s
          'HANGUP'
        end
      end

      class Ask < Message
        ##
        # Create an ask message
        #
        # @param [String] prompt to ask the caller
        # @param [String] choices to ask the user
        # @param [Hash] options for asking/prompting a specific call
        # @option options [Integer, Optional] :timeout to wait for user input
        # @option options [String, Optional] :recognizer to use for speech recognition
        # @option options [String, Optional] :voice to use for speech synthesis
        # @option options [String, Optional] :grammar to use for speech recognition (ie - application/grammar+voxeo or application/grammar+grxml)
        #
        # @return [Ozone::Message] a formatted Ozone ask message
        #
        # @example
        #    ask 'Please enter your postal code.',
        #        '[5 DIGITS]',
        #        :timeout => 30,
        #        :recognizer => 'es-es'
        #
        #    returns:
        #      <ask xmlns="urn:xmpp:ozone:ask:1" timeout="30" recognizer="es-es">
        #        <prompt>
        #          <speak>Please enter your postal code.</speak>
        #        </prompt>
        #        <choices content-type="application/grammar+voxeo">[5 DIGITS]</choices>
        #      </ask>
        def self.new(prompt, choices, options = {})
          super('ask').tap do |msg|
            Nokogiri::XML::Builder.with(msg.instance_variable_get(:@xml)) do |xml|
              xml.prompt prompt
              # Default is the Voxeo Simple Grammar, unless specified
              xml.choices("content-type" => options.delete(:grammar) || 'application/grammar+voxeo') { xml.text choices }
            end
          end
        end
      end

      class Say < Message
        ##
        # Creates a say with a text for Ozone
        #
        # @param [String] text to speak back to a caller
        #
        # @return [Ozone::Message] an Ozone "say" message
        #
        # @example
        #   say 'Hello brown cow.'
        #
        #   returns:
        #     <say xmlns="urn:xmpp:ozone:say:1">
        #       <speak>Hello brown cow.</speak>
        #     </say>
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
          super('say').tap do |msg|
            msg.set_text(options.delete(:text)) if options.has_key?(:text)
            url  = options.delete :url
            Nokogiri::XML::Builder.with(msg.instance_variable_get(:@xml)) do |xml|
              xml.audio('src' => url) if url
            end
          end
        end

        def set_text(text)
          @xml.add_child text if text
        end

        ##
        # Pauses a running Say
        #
        # @return [Ozone::Message::Say] an Ozone pause message for the current Say
        #
        # @example
        #    say_obj.pause.to_xml
        #
        #    returns:
        #      <pause xmlns="urn:xmpp:ozone:say:1"/>
        def pause
          Say.new :pause, :parent => self
        end

        ##
        # Create an Ozone resume message for the current Say
        #
        # @return [Ozone::Message::Say] an Ozone resume message
        #
        # @example
        #    say_obj.resume.to_xml
        #
        #    returns:
        #      <resume xmlns="urn:xmpp:ozone:say:1"/>
        def resume
          Say.new :resume, :parent => self
        end

        ##
        # Creates an Ozone stop message for the current Say
        #
        # @return [Ozone::Message] an Ozone stop message
        #
        # @example
        #    stop 'say'
        #
        #    returns:
        #      <stop xmlns="urn:xmpp:ozone:say:1"/>
        def stop
          Say.new :stop, :parent => self
        end
      end

      class Conference < Message

        ##
        # Creates an Ozone conference message
        #
        # @param [String] room id to with which to create or join the conference
        # @param [Hash] options for conferencing a specific call
        # @option options [String, Optional] :audio_url URL to play to the caller
        # @option options [String, Optional] :prompt Text to speak to the caller
        #
        # @return [Object] a Blather iq stanza object
        #
        # @example
        #    conference :id => 'Please enter your postal code.',
        #               :beep => true,
        #               :terminator => '#'
        #
        #    returns:
        #      <conference xmlns="urn:xmpp:ozone:conference:1" id="1234" beep="true" terminator="#"/>
        def self.new(room_id, options = {})
          conference_id = conference_id.to_s.scan(/\w/).join
          command_flags = options[:options].to_s # This is a passthrough string straight to Asterisk
          pin = options[:pin]
          raise ArgumentError, "A conference PIN number must be numerical!" if pin && pin.to_s !~ /^\d+$/

          # To disable dynamic conference creation set :use_static_conf => true
          use_static_conf = options.has_key?(:use_static_conf) ? options[:use_static_conf] : false

          # The 'd' option of MeetMe creates conferences dynamically.
          command_flags += 'd' unless (command_flags.include?('d') or use_static_conf)

          @msg = "MeetMe", conference_id, command_flags, options[:pin]
        end

        def to_s
          @msg
        end

        ##
        # Create an Ozone mute message for the current conference
        #
        # @return [Ozone::Message::Conference] an Ozone mute message
        #
        # @example
        #    conf_obj.mute.to_xml
        #
        #    returns:
        #      <mute xmlns="urn:xmpp:ozone:conference:1"/>
        def mute
          Conference.new :mute, :parent => self
        end

        ##
        # Create an Ozone unmute message for the current conference
        #
        # @return [Ozone::Message::Conference] an Ozone unmute message
        #
        # @example
        #    conf_obj.unmute.to_xml
        #
        #    returns:
        #      <unmute xmlns="urn:xmpp:ozone:conference:1"/>
        def unmute
          Conference.new :unmute, :parent => self
        end

        ##
        # Create an Ozone conference kick message
        #
        # @return [Ozone::Message::Conference] an Ozone conference kick message
        #
        # @example
        #    conf_obj.kick.to_xml
        #
        #    returns:
        #      <kick xmlns="urn:xmpp:ozone:conference:1"/>
        def kick
          Conference.new :kick, :parent => self
        end

      end

      class Transfer < Message
        ##
        # Creates a transfer message for Ozone
        #
        # @param [String] The destination for the call transfer (ie - tel:+14155551212 or sip:you@sip.tropo.com)
        #
        # @param [Hash] options for transferring a call
        # @option options [String, Optional] :terminator
        #
        # @return [Ozone::Message::Transfer] an Ozone "transfer" message
        #
        # @example
        #   Transfer.new('sip:myapp@mydomain.com', :terminator => '#').to_xml
        #
        #   returns:
        #     <transfer xmlns="urn:xmpp:ozone:transfer:1" to="sip:myapp@mydomain.com" terminator="#"/>
        def self.new(to, options = {})
          super('transfer').tap do |msg|
            options[:to] = to
            msg.set_options options
          end
        end

        def set_options options
          options.each do |option, value|
            @xml.set_attribute option.to_s, value
          end
        end
      end

      class Offer < Message
        ##
        # Creates an Offer message.
        # This message may not be sent by a client; this object is used
        # to represent an offer received from the Ozone server.
        def self.parse(xml, options)
          self.new 'offer', options
        end
      end

      class End < Message
        attr_accessor :type

        ##
        # Creates an End message.  This signifies the end of a call.
        # This message may not be sent by a client; this object is used
        # to represent an offer received from the Ozone server.
        def self.parse(xml, options)
          self.new('end', options).tap do |info|
            event = xml.first.children.first
            info.type = event.name.to_sym
          end
        end
      end

      class Info < Message
        attr_accessor :type, :attributes

        def self.parse(xml, options)
          self.new('info', options).tap do |info|
            event = xml.first.children.first
            info.type = event.name.to_sym
            info.attributes = event.attributes.inject({}) do |h, (k, v)|
              h[k.downcase.to_sym] = v.value
              h
            end
          end
        end
      end

      class Complete < Message
        attr_accessor :attributes, :xmlns

        def self.parse(xml, options)
          self.new('complete', options).tap do |info|
            info.attributes = {}
            xml.first.attributes.each { |k, v| info.attributes[k.to_sym] = v.value }
            info.xmlns = xml.first.namespace.href
          end
          # TODO: Validate response and return response type.
          # -----
          # <complete xmlns="urn:xmpp:ozone:say:1" reason="SUCCESS"/>
        end
      end
    end
  end
end
