module Punchblock
  module Protocol
    module Asterisk
      class Connection
        ##
        # This class abstracts a connection to the Asterisk Manager Interface.
        # Its purpose is, first and foremost, to make the protocol consistent.
        # Though the classes employed to assist this class
        # (ManagerInterfaceAction,ManagerInterfaceResponse,
        # ManagerInterfaceError, etc.) are relatively user-friendly, they're
        # designed to be a building block on which to build higher-level
        # abstractions of the Asterisk Manager Interface.
        class AMI
          extend ActiveSupport::Autoload

          autoload :AMILexer

          CAUSAL_EVENT_NAMES = %w[queuestatus sippeers iaxpeers parkedcalls
                                  dahdishowchannels coreshowchannels dbget
                                  status agents konferencelist] unless defined? CAUSAL_EVENT_NAMES

          RETRY_SLEEP = 5

          # class < self
          #   def replies_with_action_id?(name, headers={})
          #     name = name.to_s.downcase
          #     !UnsupportedActionName::UNSUPPORTED_ACTION_NAMES.include? name
          #   end
          #
          #   ##
          #   # When sending an action with "causal events" (i.e. events which must be collected to form a proper
          #   # response), AMI should send a particular event which instructs us that no more events will be sent.
          #   # This event is called the "causal event terminator".
          #   #
          #   # Note: you must supply both the name of the event and any headers because it's possible that some uses of an
          #   # action (i.e. same name, different headers) have causal events while other uses don't.
          #   #
          #   # @param [String] name the name of the event
          #   # @param [Hash] the headers associated with this event
          #   # @return [String] the downcase()'d name of the event name for which to wait
          #   #
          #   def has_causal_events?(name, headers={})
          #     CAUSAL_EVENT_NAMES.include? name.to_s.downcase
          #   end
          #
          #   ##
          #   # Used to determine the event name for an action which has causal events.
          #   #
          #   # @param [String] action_name
          #   # @return [String] The corresponding event name which signals the completion of the causal event sequence.
          #   #
          #   def causal_event_terminator_name_for(action_name)
          #     return nil unless has_causal_events?(action_name)
          #     action_name = action_name.to_s.downcase
          #      case action_name
          #        when "sippeers", "iaxpeers"
          #        "peerlistcomplete"
          #      when "dbget"
          #        "dbgetresponse"
          #      when "konferencelist"
          #        "conferencelistcomplete"
          #      else
          #          action_name + "complete"
          #      end
          #   end
          #
          # end

          DEFAULT_SETTINGS = {
            :host           => "localhost",
            :port           => 5038,
            :retry          => 5.seconds,
            :retry_count    => nil, # unlimited retries
          }.freeze unless defined? DEFAULT_SETTINGS

          # attr_reader *DEFAULT_SETTINGS.keys

          ##
          # Creates a new Asterisk Manager Interface connection and exposes
          # certain methods to control it. The constructor takes named
          # parameters as Symbols. Note: if the :events option is given, this
          # library will establish a separate socket for just events. Two
          # sockets are used because some actions actually respond with events,
          # making it very complicated to differentiate between response-type
          # events and normal events.
          #
          # @param [Hash] options Available options are :host, :port, :username, :password, and :events
          #
          def initialize(options = {})
            options = parse_options options
            @host           = options[:host]
            @username       = options[:username]
            @password       = options[:password]
            @port           = options[:port]

            @sent_messages = {}
            @sent_messages_lock = Mutex.new

            @actions_lexer = DelegatingAsteriskManagerInterfaceLexer.new self,
                :message_received => :action_message_received,
                :error_received   => :action_error_received

            @write_queue = Queue.new

            if @events
              @events_lexer = DelegatingAsteriskManagerInterfaceLexer.new self,
                  :message_received => :event_message_received,
                  :error_received   => :event_error_received
            end
          end
        end # AMI
      end # Connection
    end # Asterisk
  end # Protocol
end # Punchblock
