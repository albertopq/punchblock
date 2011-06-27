module Punchblock
  class Protocol
    module Event
      extend ActiveSupport::Autoload

      autoload :Answered
      autoload :Complete
      autoload :End
      autoload :Info
      autoload :Offer
      autoload :Ringing
    end
  end
end
