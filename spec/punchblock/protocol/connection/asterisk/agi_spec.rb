require 'spec_helper'

module Punchblock
  class Protocol
    module Connection
      class Asterisk
        class AGI
          describe CallServer do
            before { pending }

            it 'should instantiate a new Call with the IO object it receives' do
              io_mock   = flexmock "Mock IO object that's passed to the serve() method"
              call_mock = flexmock "A Call mock that's returned by Adhearsion#receive_call_from", :variable => {}
              flexstub(server_class).should_receive(:ahn_log)
              the_following_code {
                flexmock(Adhearsion).should_receive(:receive_call_from).once.with(io_mock).and_throw :created_call!
                server.serve(io_mock)
              }.should throw_symbol :created_call!
            end

            it 'should hand the call off to a new Manager if the request is agi://IP_ADDRESS_HERE' do
              call_mock = flexmock 'A new mock call that will be passed to the manager', :variables => {}, :unique_identifier => "X"

              flexmock(Adhearsion).should_receive(:receive_call_from).once.and_return call_mock
              manager_mock = flexmock 'a mock dialplan manager'
              manager_mock.should_receive(:handle).once.with(call_mock)
              flexmock(Adhearsion::DialPlan::Manager).should_receive(:new).once.and_return manager_mock
              server.serve(nil)
            end

            it 'should execute the hungup_call event when a HungupExtensionCallException is raised' do
              call_mock = flexmock 'a bogus call', :hungup_call? => true, :variables => {:extension => "h"}, :unique_identifier => "X"
              mock_env  = flexmock "A mock execution environment which gets passed along in the HungupExtensionCallException"

              stub_confirmation_manager!
              flexstub(Adhearsion).should_receive(:receive_call_from).once.and_return(call_mock)
              flexmock(Adhearsion::DialPlan::Manager).should_receive(:handle).once.and_raise Adhearsion::HungupExtensionCallException.new(mock_env)
              flexmock(Adhearsion::Events).should_receive(:trigger).once.with([:asterisk, :hungup_call], mock_env).and_throw :hungup_call

              the_following_code { server.serve nil }.should throw_symbol :hungup_call
            end

            it 'should execute the OnFailedCall hooks when a FailedExtensionCallException is raised' do
              call_mock = flexmock 'a bogus call', :failed_call? => true, :variables => {:extension => "failed"}, :unique_identifier => "X"
              mock_env  = flexmock "A mock execution environment which gets passed along in the HungupExtensionCallException", :failed_reason => "does not matter"

              server = Adhearsion::VoIP::Asterisk::AGI::Server::RubyServer.new :port, :host

              flexmock(Adhearsion).should_receive(:receive_call_from).once.and_return(call_mock)
              flexmock(Adhearsion::DialPlan::Manager).should_receive(:handle).once.and_raise Adhearsion::FailedExtensionCallException.new(mock_env)
              flexmock(Adhearsion::Events).should_receive(:trigger).once.with([:asterisk, :failed_call], mock_env).and_throw :failed_call
              the_following_code { server.serve nil }.should throw_symbol :failed_call
            end
          end
        end
      end # Asterisk
    end # Connection
  end # Protocol
end # Punchblock
