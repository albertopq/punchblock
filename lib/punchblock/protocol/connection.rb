module Punchblock
  class Protocol
    module Connection
      extend ActiveSupport::Autoload

      autoload :GenericConnection
      autoload :Internal
      autoload :Translator
      autoload :XMPP

      def self.create(options = {})
        ({:internal => Internal, :xmpp => XMPP}[options.delete(:connection_type)] || XMPP).new options
      end
    end
  end
end
