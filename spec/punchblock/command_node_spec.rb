require 'spec_helper'

module Punchblock
  module Command
    describe CommandNode do
      its(:state_name) { should == :new }

      describe "#new" do
        describe "with a call/component ID" do
          let(:call_id)       { 'abc123' }
          let(:component_id)  { 'abc123' }
          let(:args)          { [{:call_id => call_id, :component_id => component_id}] }

          subject { CommandNode.new *args }

          its(:call_id)       { should == call_id }
          its(:component_id)  { should == component_id }
        end
      end

      describe "#request!" do
        before { subject.request! }

        its(:state_name) { should == :requested }

        it "should raise a StateMachine::InvalidTransition when received a second time" do
          lambda { subject.request! }.should raise_error(StateMachine::InvalidTransition)
        end

        it "should prevent altering attributes" do
          lambda { subject.write_attr :foo, 'bar' }.should raise_error(StandardError, "Cannot alter attributes of a requested command")
        end
      end

      describe "#execute!" do
        describe "without sending" do
          it "should raise a StateMachine::InvalidTransition" do
            lambda { subject.execute! }.should raise_error(StateMachine::InvalidTransition)
          end
        end

        describe "after sending" do
          before do
            subject.request!
            subject.execute!
          end

          its(:state_name) { should == :executing }
        end
      end

      describe "#complete!" do
        before do
          subject.request!
          subject.execute!
          subject.complete!
        end

        its(:state_name) { should == :complete }

        it "should raise a StateMachine::InvalidTransition when received a second time" do
          lambda { subject.complete! }.should raise_error(StateMachine::InvalidTransition)
        end
      end # #complete!

      describe "#response=" do
        it "should set the command to executing status" do
          subject.expects(:execute!).once
          subject.response = :foo
        end

        it "should be a no-op if the response has already been set" do
          subject.expects(:execute!).once
          subject.response = :foo
          lambda { subject.response = :bar }.should_not raise_error
        end
      end
    end # CommandNode
  end # Command
end # Punchblock
