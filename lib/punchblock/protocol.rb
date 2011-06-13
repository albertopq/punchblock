module Punchblock
  module Protocol
    extend ActiveSupport::Autoload

    autoload :GenericConnection
    autoload :Asterisk
    autoload :Ozone
    autoload :ProtocolError
  end
end
