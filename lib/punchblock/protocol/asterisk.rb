module Punchblock
  class Protocol
    module Asterisk
      extend ActiveSupport::Autoload

      autoload :Command
      autoload :Message
    end # Asterisk
  end # Protocol
end # Punchblock
