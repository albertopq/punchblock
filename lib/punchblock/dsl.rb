##
# DO NOT USE THIS API!
# This file is temporary, to help make testing Punchblock easier.
# THIS IS IMPERMANENT AND WILL DISAPPEAR
module Punchblock
  class DSL
    def initialize(protocol, call, queue) # :nodoc:
      @protocol, @call, @queue = protocol, call, queue
    end

    def accept # :nodoc:
      write Protocol::Command::Accept.new
    end

    def answer # :nodoc:
      write Protocol::Command::Answer.new
    end

    def hangup # :nodoc:
      write Protocol::Command::Hangup.new
    end

    def reject(reason = nil) # :nodoc:
      write Protocol::Command::Reject.new(:reason => reason)
    end

    def redirect(dest) # :nodoc:
      write Protocol::Command::Redirect.new(:to => dest)
    end

    def say(string, type = :text) # :nodoc:
      write Protocol::Command::Say.new(type => string)
      puts "Waiting on the queue..."
      response = @queue.pop
      # TODO: Error handling
    end

    def write(msg) # :nodoc:
      @protocol.write @call, msg
    end
  end
end
