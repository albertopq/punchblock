require 'eventmachine'

module Punchblock
  class Protocol
    module Connection
      class Asterisk < GenericConnection
        extend ActiveSupport::Autoload

        autoload :AMI
        autoload :AGI
        autoload :Call

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

        ##
        # Initialize the required connection attributes
        #
        # @param [Hash] options
        # @option options [Hash] agi
        # @option agi [String] :username client JID
        # @option agi [String] :password XMPP password
        # @option options [Hash] ami
        # @option ami [String] :ozone_domain the domain on which Ozone is running
        # @option options [Logger, Optional] :wire_logger to which all AGI/AMI transactions will be logged
        #
        def initialize(options = {})
          super
          options[:ami] = DEFAULT_OPTIONS[:ami].merge options[:ami] || {}
          options[:agi] = DEFAULT_OPTIONS[:agi].merge options[:agi] || {}
          raise ArgumentError, "You must supply configuration for Asterisk AMI" unless options.has_key? :ami
          raise ArgumentError, "You must supply a username for Asterisk AMI" unless options[:ami].has_key? :username
          raise ArgumentError, "You must supply a password for Asterisk AMI" unless options[:ami].has_key? :password
          @ami = AMI.new options[:ami].merge(:connection => self)
          @agi = AGI.new options[:agi].merge(:connection => self)

          @wire_logger = options.delete(:wire_logger) if options.has_key?(:wire_logger)
        end

        ##
        # Fire up the connection
        #
        def run
          @ami.run
          @agi.run
        end
      end
    end
  end
end
