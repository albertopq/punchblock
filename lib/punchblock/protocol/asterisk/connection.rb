module Punchblock
  class Protocol
    module Asterisk
      class Connection < GenericConnection
        extend ActiveSupport::Autoload

        autoload :AMI
        autoload :AGI

        DEFAULT_OPTIONS = {
          :agi => {
            :listening_addr => '::',
            :listening_port => 4573,
          },
          :ami => {
            :host => '::1',
            :port => 5038,
          },
        }

        attr_accessor :event_queue

        def initialize(options = {})
          super
          options[:ami] = DEFAULT_OPTIONS[:ami].merge options[:ami]
          options[:agi] = DEFAULT_OPTIONS[:agi].merge options[:agi]
          raise ArgumentError unless options.has_key? :ami
          raise ArgumentError unless options[:ami].has_key? :user
          raise ArgumentError unless options[:ami].has_key? :pass
          @ami = AMI.new options[:ami]
          @agi = AGI.new options[:agi]
        end
      end # Connection
    end # Asterisk
  end # Protocol
end # Punchblock
