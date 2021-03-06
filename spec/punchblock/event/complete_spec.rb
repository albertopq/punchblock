require 'spec_helper'

module Punchblock
  class Event
    describe Complete do
      it 'registers itself' do
        RayoNode.class_from_registration(:complete, 'urn:xmpp:rayo:ext:1').should == Complete
      end

      describe "comparing for equality" do
        subject do
          Complete.new.tap do |c|
            c.reason        = Complete::Stop.new
            c.call_id       = '1234'
            c.component_id  = 'abcd'
          end
        end

        let :other_complete do
          Complete.new.tap do |c|
            c.reason        = reason
            c.call_id       = call_id
            c.component_id  = component_id
          end
        end

        context 'with reason, call id and component id the same' do
          let(:reason)        { Complete::Stop.new }
          let(:call_id)       { '1234' }
          let(:component_id)  { 'abcd' }

          it "should be equal" do
            subject.should == other_complete
          end
        end

        context 'with a different reason' do
          let(:reason)        { Complete::Hangup.new }
          let(:call_id)       { '1234' }
          let(:component_id)  { 'abcd' }

          it "should not be equal" do
            subject.should_not == other_complete
          end
        end

        context 'with a different call id' do
          let(:reason)        { Complete::Stop.new }
          let(:call_id)       { '5678' }
          let(:component_id)  { 'abcd' }

          it "should not be equal" do
            subject.should_not == other_complete
          end
        end

        context 'with a different component id' do
          let(:reason)        { Complete::Stop.new }
          let(:call_id)       { '1234' }
          let(:component_id)  { 'efgh' }

          it "should not be equal" do
            subject.should_not == other_complete
          end
        end
      end

      describe "from a stanza" do
        let :stanza do
          <<-MESSAGE
<complete xmlns='urn:xmpp:rayo:ext:1'>
  <success xmlns='urn:xmpp:rayo:output:complete:1' />
</complete>
          MESSAGE
        end

        subject { RayoNode.import parse_stanza(stanza).root, '9f00061', '1' }

        it { should be_instance_of Complete }

        it_should_behave_like 'event'

        its(:reason) { should be_instance_of Component::Output::Complete::Success }
      end
    end

    describe Complete::Stop do
      let :stanza do
        <<-MESSAGE
<complete xmlns='urn:xmpp:rayo:ext:1'>
  <stop xmlns='urn:xmpp:rayo:ext:complete:1' />
</complete>
        MESSAGE
      end

      subject { RayoNode.import(parse_stanza(stanza).root).reason }

      it { should be_instance_of Complete::Stop }

      its(:name) { should == :stop }
    end

    describe Complete::Hangup do
      let :stanza do
        <<-MESSAGE
<complete xmlns='urn:xmpp:rayo:ext:1'>
  <hangup xmlns='urn:xmpp:rayo:ext:complete:1' />
</complete>
        MESSAGE
      end

      subject { RayoNode.import(parse_stanza(stanza).root).reason }

      it { should be_instance_of Complete::Hangup }

      its(:name) { should == :hangup }
    end

    describe Complete::Error do
      let :stanza do
        <<-MESSAGE
<complete xmlns='urn:xmpp:rayo:ext:1'>
  <error xmlns='urn:xmpp:rayo:ext:complete:1'>
    Something really bad happened
  </error>
</complete>
        MESSAGE
      end

      subject { RayoNode.import(parse_stanza(stanza).root).reason }

      it { should be_instance_of Complete::Error }

      its(:name) { should == :error }
      its(:details) { should == "Something really bad happened" }

      describe "when setting options in initializer" do
        subject do
          Complete::Error.new :details => 'Ooops'
        end

        its(:details) { should == 'Ooops' }
      end
    end
  end
end # Punchblock
