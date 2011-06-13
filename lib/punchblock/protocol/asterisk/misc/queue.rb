          # Place a call in a queue to be answered by a registered agent. You must then call join!()
          #
          # @param [String] queue_name the queue name to place the caller in
          # @return [Adhearsion::VoIP::Asterisk::Commands::QueueProxy] a queue proxy object
          #
          # @see http://www.voip-info.org/wiki-Asterisk+cmd+Queue Full information on the Asterisk Queue
          # @see Adhearsion::VoIP::Asterisk::Commands::QueueProxy#join! join!() for further details
          def queue(queue_name)
            queue_name = queue_name.to_s

            @queue_proxy_hash_lock = Mutex.new unless defined? @queue_proxy_hash_lock
            @queue_proxy_hash_lock.synchronize do
              @queue_proxy_hash ||= {}
              if @queue_proxy_hash.has_key? queue_name
                return @queue_proxy_hash[queue_name]
              else
                proxy = @queue_proxy_hash[queue_name] = QueueProxy.new(queue_name, self)
                return proxy
              end
            end
          end




            class QueueProxy

              class << self

                def format_join_hash_key_arguments(options)

                  bad_argument = lambda do |(key, value)|
                    raise ArgumentError, "Unrecognize value for #{key.inspect} -- #{value.inspect}"
                  end

                  # Direct Queue() arguments:
                  timeout        = options.delete :timeout
                  announcement   = options.delete :announce

                  # Terse single-character options
                  ring_style     = options.delete :play
                  allow_hangup   = options.delete :allow_hangup
                  allow_transfer = options.delete :allow_transfer
                  agi            = options.delete :agi

                  raise ArgumentError, "Unrecognized args to join!: #{options.inspect}" if options.any?

                  ring_style = case ring_style
                    when :ringing then 'r'
                    when :music then   ''
                    when nil
                    else bad_argument[:play => ring_style]
                  end.to_s

                  allow_hangup = case allow_hangup
                    when :caller then   'H'
                    when :agent then    'h'
                    when :everyone then 'Hh'
                    when nil
                    else bad_argument[:allow_hangup => allow_hangup]
                  end.to_s

                  allow_transfer = case allow_transfer
                    when :caller then   'T'
                    when :agent then    't'
                    when :everyone then 'Tt'
                    when nil
                    else bad_argument[:allow_transfer => allow_transfer]
                  end.to_s

                  terse_character_options = ring_style + allow_transfer + allow_hangup

                  [terse_character_options, '', announcement, timeout, agi].map(&:to_s)
                end

              end

              attr_reader :name, :environment
              def initialize(name, environment)
                @name, @environment = name, environment
              end

              # Makes the current channel join the queue.
              #
              # @param [Hash] options
              #
              #   :timeout        - The number of seconds to wait for an agent to answer
              #   :play           - Can be :ringing or :music.
              #   :announce       - A sound file to play instead of the normal queue announcement.
              #   :allow_transfer - Can be :caller, :agent, or :everyone. Allow someone to transfer the call.
              #   :allow_hangup   - Can be :caller, :agent, or :everyone. Allow someone to hangup with the * key.
              #   :agi            - An AGI script to be called on the calling parties channel just before being connected.
              #
              #  @example
              #    queue('sales').join!
              #  @example
              #    queue('sales').join! :timeout => 1.minute
              #  @example
              #    queue('sales').join! :play => :music
              #  @example
              #    queue('sales').join! :play => :ringing
              #  @example
              #    queue('sales').join! :announce => "custom/special-queue-announcement"
              #  @example
              #    queue('sales').join! :allow_transfer => :caller
              #  @example
              #    queue('sales').join! :allow_transfer => :agent
              #  @example
              #    queue('sales').join! :allow_hangup   => :caller
              #  @example
              #    queue('sales').join! :allow_hangup   => :agent
              #  @example
              #    queue('sales').join! :allow_hangup   => :everyone
              #  @example
              #    queue('sales').join! :agi            => 'agi://localhost/sales_queue_callback'
              #  @example
              #    queue('sales').join! :allow_transfer => :agent, :timeout => 30.seconds,
              def join!(options={})
                environment.execute("queue", name, *self.class.format_join_hash_key_arguments(options))
                normalize_queue_status_variable environment.variable("QUEUESTATUS")
              end

              # Get the agents associated with a queue
              #
              # @param [Hash] options
              # @return [QueueAgentsListProxy]
              def agents(options={})
                cached = options.has_key?(:cache) ? options.delete(:cache) : true
                raise ArgumentError, "Unrecognized arguments to agents(): #{options.inspect}" if options.keys.any?
                if cached
                  @cached_proxy ||= QueueAgentsListProxy.new(self, true)
                else
                  @uncached_proxy ||=  QueueAgentsListProxy.new(self, false)
                end
              end

              # Check how many channels are waiting in the queue
              # @return [Integer]
              # @raise QueueDoesNotExistError
              def waiting_count
                raise QueueDoesNotExistError.new(name) unless exists?
                environment.variable("QUEUE_WAITING_COUNT(#{name})").to_i
              end

              # Check whether the waiting count is zero
              # @return [Boolean]
              def empty?
                waiting_count == 0
              end

              # Check whether any calls are waiting in the queue
              # @return [Boolean]
              def any?
                waiting_count > 0
              end

              # Check whether a queue exists/is defined in Asterisk
              # @return [Boolean]
              def exists?
                environment.execute('RemoveQueueMember', name, 'SIP/AdhearsionQueueExistenceCheck')
                environment.variable("RQMSTATUS") != 'NOSUCHQUEUE'
              end

              private

              # Ensure the queue exists by interpreting the QUEUESTATUS variable
              #
              # According to http://www.voip-info.org/wiki/view/Asterisk+cmd+Queue
              # possible values are:
              #
              # TIMEOUT      => :timeout
              # FULL         => :full
              # JOINEMPTY    => :joinempty
              # LEAVEEMPTY   => :leaveempty
              # JOINUNAVAIL  => :joinunavail
              # LEAVEUNAVAIL => :leaveunavail
              # CONTINUE     => :continue
              #
              # If the QUEUESTATUS variable is not set the call was successfully connected,
              # and Adhearsion will return :completed.
              #
              # @param [String] QUEUESTATUS variable from Asterisk
              # @return [Symbol] Symbolized version of QUEUESTATUS
              # @raise QueueDoesNotExistError
              def normalize_queue_status_variable(variable)
                variable = "COMPLETED" if variable.nil?
                variable.downcase.to_sym
              end

              class QueueAgentsListProxy

                include Enumerable

                attr_reader :proxy, :agents
                def initialize(proxy, cached=false)
                  @proxy  = proxy
                  @cached = cached
                end

                def count
                  if cached? && @cached_count
                    @cached_count
                  else
                    @cached_count = proxy.environment.variable("QUEUE_MEMBER_COUNT(#{proxy.name})").to_i
                  end
                end
                alias size count
                alias length count

                # @param [Hash] args
                # :name value will be viewable in the queue_log
                # :penalty is the penalty assigned to this agent for answering calls on this queue
                def new(*args)

                  options   = args.last.kind_of?(Hash) ? args.pop : {}
                  interface = args.shift

                  raise ArgumentError, "You must specify an interface to add." if interface.nil?
                  raise ArgumentError, "You may only supply an interface and a Hash argument!" if args.any?

                  penalty             = options.delete(:penalty)            || ''
                  name                = options.delete(:name)               || ''
                  state_interface     = options.delete(:state_interface)    || ''

                  raise ArgumentError, "Unrecognized argument(s): #{options.inspect}" if options.any?

                  proxy.environment.execute("AddQueueMember", proxy.name, interface, penalty, '', name, state_interface)

                  added = case proxy.environment.variable("AQMSTATUS")
                          when "ADDED"         then true
                          when "MEMBERALREADY" then false
                          when "NOSUCHQUEUE"   then raise QueueDoesNotExistError.new(proxy.name)
                          else
                            raise "UNRECOGNIZED AQMSTATUS VALUE!"
                          end

                  if added
                    check_agent_cache!
                    AgentProxy.new(interface, proxy).tap do |agent_proxy|
                      @agents << agent_proxy
                    end
                  else
                    false
                  end
                end

                # Logs a pre-defined agent into this queue and waits for calls. Pass in :silent => true to stop
                # the message which says "Agent logged in".
                def login!(*args)
                  options = args.last.kind_of?(Hash) ? args.pop : {}

                  silent = options.delete(:silent).equal?(false) ? '' : 's'
                  id     = args.shift
                  id   &&= AgentProxy.id_from_agent_channel(id)
                  raise ArgumentError, "Unrecognized Hash options to login(): #{options.inspect}" if options.any?
                  raise ArgumentError, "Unrecognized argument to login(): #{args.inspect}" if args.any?

                  proxy.environment.execute('AgentLogin', id, silent)
                end

                # Removes the current channel from this queue
                def logout!
                  # TODO: DRY this up. Repeated in the AgentProxy...
                  proxy.environment.execute 'RemoveQueueMember', proxy.name
                  case proxy.environment.variable("RQMSTATUS")
                    when "REMOVED"     then true
                    when "NOTINQUEUE"  then false
                    when "NOSUCHQUEUE"
                      raise QueueDoesNotExistError.new(proxy.name)
                    else
                      raise "Unrecognized RQMSTATUS variable!"
                  end
                end

                def each(&block)
                  check_agent_cache!
                  agents.each(&block)
                end

                def first
                  check_agent_cache!
                  agents.first
                end

                def last
                  check_agent_cache!
                  agents.last
                end

                def cached?
                  @cached
                end

                def to_a
                  check_agent_cache!
                  @agents
                end

                private

                def check_agent_cache!
                  if cached?
                    load_agents! unless agents
                  else
                    load_agents!
                  end
                end

                def load_agents!
                  raw_data = proxy.environment.variable "QUEUE_MEMBER_LIST(#{proxy.name})"
                  @agents = raw_data.split(',').map(&:strip).reject(&:empty?).map do |agent|
                    AgentProxy.new(agent, proxy)
                  end
                  @cached_count = @agents.size
                end

              end

              class AgentProxy

                SUPPORTED_METADATA_NAMES = %w[status password name mohclass exten channel] unless defined? SUPPORTED_METADATA_NAMES

                class << self
                  def id_from_agent_channel(id)
                    id = id.to_s
                    id.starts_with?('Agent/') ? id[%r[^Agent/(.+)$],1] : id
                  end
                end

                attr_reader :interface, :proxy, :queue_name, :id
                def initialize(interface, proxy)
                  @interface  = interface
                  @id         = self.class.id_from_agent_channel interface
                  @proxy      = proxy
                  @queue_name = proxy.name
                end

                def remove!
                  proxy.environment.execute 'RemoveQueueMember', queue_name, interface
                  case proxy.environment.variable("RQMSTATUS")
                    when "REMOVED"     then true
                    when "NOTINQUEUE"  then false
                    when "NOSUCHQUEUE"
                      raise QueueDoesNotExistError.new(queue_name)
                    else
                      raise "Unrecognized RQMSTATUS variable!"
                  end
                end

                # Pauses the given agent for this queue only. If you wish to pause this agent
                # for all queues, pass in :everywhere => true. Returns true if the agent was
                # successfully paused and false if the agent was not found.
                def pause!(options={})
                  everywhere = options.delete(:everywhere)
                  args = [(everywhere ? nil : queue_name), interface]
                  proxy.environment.execute('PauseQueueMember', *args)
                  case proxy.environment.variable("PQMSTATUS")
                    when "PAUSED"   then true
                    when "NOTFOUND" then false
                    else
                      raise "Unrecognized PQMSTATUS value!"
                  end
                end

                # Pauses the given agent for this queue only. If you wish to pause this agent
                # for all queues, pass in :everywhere => true. Returns true if the agent was
                # successfully paused and false if the agent was not found.
                def unpause!(options={})
                  everywhere = options.delete(:everywhere)
                  args = [(everywhere ? nil : queue_name), interface]
                  proxy.environment.execute('UnpauseQueueMember', *args)
                  case proxy.environment.variable("UPQMSTATUS")
                    when "UNPAUSED" then true
                    when "NOTFOUND" then false
                    else
                      raise "Unrecognized UPQMSTATUS value!"
                  end
                end

                # Returns true/false depending on whether this agent is logged in.
                def logged_in?
                  status == 'LOGGEDIN'
                end

                private

                def status
                  agent_metadata 'status'
                end

                def agent_metadata(data_name)
                  data_name = data_name.to_s.downcase
                  raise ArgumentError, "unrecognized agent metadata name #{data_name}" unless SUPPORTED_METADATA_NAMES.include? data_name
                  proxy.environment.variable "AGENT(#{id}:#{data_name})"
                end

              end

              class QueueDoesNotExistError < StandardError
                def initialize(queue_name)
                  super "Queue #{queue_name} does not exist!"
                end
              end

            end
