require 'spec_helper'

module Punchblock
  class Protocol
    module Connection
      module Translator
        describe Asterisk do
          let :valid_options do
            {
              :ami => {
                :username => 'example',
                :password => 'password'
              }
            }
          end

          subject { Asterisk.new valid_options }

          describe "creation" do
            it "raises ArgumentError without an AMI username" do
              lambda do
                Asterisk.new valid_options.tap { |o| o[:ami].delete :username }
              end.should raise_error(ArgumentError, "You must supply a username for Asterisk AMI")
            end

            it "raises ArgumentError without an AMI password" do
              lambda do
                Asterisk.new valid_options.tap { |o| o[:ami].delete :password }
              end.should raise_error(ArgumentError, "You must supply a password for Asterisk AMI")
            end

            it "creates an AGI instance for this connection" do
              subject.agi.should be_a Asterisk::AGI
              subject.agi.connection.should == subject
            end

            it "creates an AMI instance for this connection" do
              subject.ami.should be_a Asterisk::AMI
              subject.ami.connection.should == subject
            end
          end

          describe "#run" do
            it "should run AGI and AMI" do
              subject.agi.expects :run
              subject.ami.expects :run
              subject.run
            end
          end

          describe "#notify_new_call" do
            it "should map call ID to AGI server" do
              subject.notify_new_call 'foo', :bar
              subject.call_server_for_id('foo').should == :bar
            end
          end
        end # Asterisk
      end # Translator
    end # Connection
  end # Protocol
end # Punchblock
