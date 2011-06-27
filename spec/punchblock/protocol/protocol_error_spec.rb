require 'spec_helper'

module Punchblock
  class Protocol
    describe ProtocolError do
      subject { ProtocolError.new :item_not_found, 'Could not find call [id=f6d437f4-1e18-457b-99f8-b5d853f50347]', 'f6d437f4-1e18-457b-99f8-b5d853f50347', 'abc123' }

      its(:inspect) { should == '#<Punchblock::Protocol::ProtocolError: name=:item_not_found text="Could not find call [id=f6d437f4-1e18-457b-99f8-b5d853f50347]" call_id="f6d437f4-1e18-457b-99f8-b5d853f50347" command_id="abc123">' }
    end
  end
end
