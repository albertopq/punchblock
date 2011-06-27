require 'spec_helper'

module Punchblock
  class Protocol
    module Command
      describe Accept do
        it 'registers itself' do
          OzoneNode.class_from_registration(:accept, 'urn:xmpp:ozone:1').should == Accept
        end

        it_should_behave_like 'command_headers'
      end
    end
  end # Protocol
end # Punchblock
