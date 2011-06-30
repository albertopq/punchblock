require 'spec_helper'

module Punchblock
  class Protocol
    module Connection
      describe Internal do
        let(:translator) { Translator::Asterisk.new :ami => {:username => 'foo', :password => :bar} }

        subject { Internal.new :translator => translator }

        describe "on initialization" do
          its(:write_queue) { should be_a Queue }
          its(:event_queue) { should == translator.event_queue }
        end

        describe "#run" do
          it "should run the translator" do
            translator.expects(:run)
            subject.run
          end
        end
      end # Internal
    end # Connection
  end # Protocol
end # Punchblock
