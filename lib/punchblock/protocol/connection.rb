module Punchblock
  class Protocol
    module Connection
      extend ActiveSupport::Autoload

      autoload :GenericConnection
      autoload :XMPP

      def self.create(options = {})
        ({:xmpp => XMPP}[options.delete(:connection_type)] || XMPP).new options
      end
    end
  end
end
