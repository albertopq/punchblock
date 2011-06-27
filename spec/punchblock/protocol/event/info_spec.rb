require 'spec_helper'

module Punchblock
  class Protocol
    module Event
      describe Info do
        it 'registers itself' do
          OzoneNode.class_from_registration(:info, 'urn:xmpp:ozone:1').should == Info
        end

        describe "from a stanza" do
          let :stanza do
            <<-MESSAGE
<info xmlns='urn:xmpp:ozone:1'>
  <something/>
</info>
            MESSAGE
          end

          subject { OzoneNode.import parse_stanza(stanza).root, '9f00061', '1' }

          it { should be_instance_of Info }

          it_should_behave_like 'event'

          its(:event_name) { should == :something }
          its(:xmlns) { should == 'urn:xmpp:ozone:1' }
        end
      end
    end
  end # Protocol
end # Punchblock
