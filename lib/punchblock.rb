require 'active_support/dependencies/autoload'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/numeric/time'

module Punchblock
  extend ActiveSupport::Autoload

  autoload :Call
  autoload :DSL
  autoload :Protocol

  ##
  # This exception may be raised if a transport error is detected.
  TransportError = Class.new StandardError
end
