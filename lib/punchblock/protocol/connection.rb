module Punchblock
  class Protocol
    module Connection
      extend ActiveSupport::Autoload

      autoload :Asterisk
      autoload :GenericConnection
      autoload :XMPP

      def self.create(options = {})
        ({:asterisk => Asterisk, :xmpp => XMPP}[options.delete(:connection_type)] || XMPP).new options
      end
    end
  end
end
