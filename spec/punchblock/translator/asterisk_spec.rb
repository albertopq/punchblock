require 'spec_helper'

module Punchblock
  module Translator
    describe Asterisk do
      let(:ami_client)    { mock 'RubyAMI::Client' }
      let(:connection)    { mock 'Connection::Asterisk' }
      let(:media_engine)  { :asterisk }

      let(:translator) { Asterisk.new ami_client, connection, media_engine }

      subject { translator }

      its(:ami_client) { should be ami_client }
      its(:connection) { should be connection }

      after { translator.terminate if translator.alive? }

      context 'with a configured media engine of :asterisk' do
        let(:media_engine) { :asterisk }
        its(:media_engine) { should == :asterisk }
      end

      context 'with a configured media engine of :unimrcp' do
        let(:media_engine) { :unimrcp }
        its(:media_engine) { should == :unimrcp }
      end

      describe '#shutdown' do
        it "instructs all calls to shutdown" do
          call = Asterisk::Call.new 'foo', subject
          call.expects(:shutdown!).once
          subject.register_call call
          subject.shutdown
        end

        it "terminates the actor" do
          subject.shutdown
          subject.should_not be_alive
        end
      end

      describe '#execute_command' do
        describe 'with a call command' do
          let(:command) { Command::Answer.new }
          let(:call_id) { 'abc123' }

          it 'executes the call command' do
            subject.wrapped_object.expects(:execute_call_command).with do |c|
              c.should be command
              c.call_id.should == call_id
            end
            subject.execute_command command, :call_id => call_id
          end
        end

        describe 'with a global component command' do
          let(:command)       { Component::Stop.new }
          let(:component_id)  { '123abc' }

          it 'executes the component command' do
            subject.wrapped_object.expects(:execute_component_command).with do |c|
              c.should be command
              c.component_id.should == component_id
            end
            subject.execute_command command, :component_id => component_id
          end
        end

        describe 'with a global command' do
          let(:command) { Command::Dial.new }

          it 'executes the command directly' do
            subject.wrapped_object.expects(:execute_global_command).with command
            subject.execute_command command
          end
        end
      end

      describe '#register_call' do
        let(:call_id) { 'abc123' }
        let(:channel) { 'SIP/foo' }
        let(:call)    { Translator::Asterisk::Call.new channel, subject }

        before do
          call.stubs(:id).returns call_id
          subject.register_call call
        end

        it 'should make the call accessible by ID' do
          subject.call_with_id(call_id).should be call
        end

        it 'should make the call accessible by channel' do
          subject.call_for_channel(channel).should be call
        end
      end

      describe '#register_component' do
        let(:component_id) { 'abc123' }
        let(:component)    { mock 'Asterisk::Component::Asterisk::AMIAction', :id => component_id }

        it 'should make the component accessible by ID' do
          subject.register_component component
          subject.component_with_id(component_id).should be component
        end
      end

      describe '#execute_call_command' do
        let(:call_id) { 'abc123' }
        let(:call)    { Translator::Asterisk::Call.new 'SIP/foo', subject }
        let(:command) { Command::Answer.new.tap { |c| c.call_id = call_id } }

        before do
          command.request!
          call.stubs(:id).returns call_id
        end

        context "with a known call ID" do
          before do
            subject.register_call call
          end

          it 'sends the command to the call for execution' do
            call.expects(:execute_command!).once.with command
            subject.execute_call_command command
          end
        end

        context "with an unknown call ID" do
          it 'sends an error in response to the command' do
            subject.execute_call_command command
            command.response.should == ProtocolError.new('call-not-found', "Could not find a call with ID #{call_id}", call_id, nil)
          end
        end
      end

      describe '#execute_component_command' do
        let(:component_id)  { '123abc' }
        let(:component)     { mock 'Translator::Asterisk::Component', :id => component_id }

        let(:command) { Component::Stop.new.tap { |c| c.component_id = component_id } }

        before do
          command.request!
        end

        context 'with a known component ID' do
          before do
            subject.register_component component
          end

          it 'sends the command to the component for execution' do
            component.expects(:execute_command!).once.with command
            subject.execute_component_command command
          end
        end

        context "with an unknown component ID" do
          it 'sends an error in response to the command' do
            subject.execute_component_command command
            command.response.should == ProtocolError.new('component-not-found', "Could not find a component with ID #{component_id}", nil, component_id)
          end
        end
      end

      describe '#execute_global_command' do
        context 'with a Dial' do
          let :command do
            Command::Dial.new :to => 'SIP/1234', :from => 'abc123'
          end

          before do
            command.request!
            ami_client.stub_everything
          end

          it 'should be able to look up the call by channel ID' do
            subject.execute_global_command command
            call_actor = subject.call_for_channel('SIP/1234')
            call_actor.wrapped_object.should be_a Asterisk::Call
          end

          it 'should instruct the call to send a dial' do
            mock_call = stub_everything 'Asterisk::Call'
            Asterisk::Call.expects(:new).once.returns mock_call
            mock_call.expects(:dial!).once.with command
            subject.execute_global_command command
          end
        end

        context 'with an AMI action' do
          let :command do
            Component::Asterisk::AMI::Action.new :name => 'Status', :params => { :channel => 'foo' }
          end

          let(:mock_action) { stub_everything 'Asterisk::Component::Asterisk::AMIAction' }

          it 'should create a component actor and execute it asynchronously' do
            Asterisk::Component::Asterisk::AMIAction.expects(:new).once.with(command, subject).returns mock_action
            mock_action.expects(:execute!).once
            subject.execute_global_command command
          end

          it 'registers the component' do
            Asterisk::Component::Asterisk::AMIAction.expects(:new).once.with(command, subject).returns mock_action
            subject.wrapped_object.expects(:register_component).with mock_action
            subject.execute_global_command command
          end
        end

        context "with a command we don't understand" do
          let :command do
            Command::Answer.new
          end

          it 'sends an error in response to the command' do
            subject.execute_command command
            command.response.should == ProtocolError.new('command-not-acceptable', "Did not understand command")
          end
        end
      end

      describe '#handle_pb_event' do
        it 'should forward the event to the connection' do
          event = mock 'Punchblock::Event'
          subject.connection.expects(:handle_event).once.with event
          subject.handle_pb_event event
        end
      end

      describe '#handle_ami_event' do
        let :ami_event do
          RubyAMI::Event.new('Newchannel').tap do |e|
            e['Channel']  = "SIP/101-3f3f"
            e['State']    = "Ring"
            e['Callerid'] = "101"
            e['Uniqueid'] = "1094154427.10"
          end
        end

        let :expected_pb_event do
          Event::Asterisk::AMI::Event.new :name => 'Newchannel',
                                          :attributes => { :channel  => "SIP/101-3f3f",
                                                           :state    => "Ring",
                                                           :callerid => "101",
                                                           :uniqueid => "1094154427.10"}
        end

        it 'should create a Punchblock AMI event object and pass it to the connection' do
          subject.connection.expects(:handle_event).once.with expected_pb_event
          subject.handle_ami_event ami_event
        end

        context 'with something that is not a RubyAMI::Event' do
          it 'does not send anything to the connection' do
            subject.connection.expects(:handle_event).never
            subject.handle_ami_event :foo
          end
        end

        describe 'with a FullyBooted event' do
          let(:ami_event) { RubyAMI::Event.new 'FullyBooted' }

          context 'once' do
            it 'does not send anything to the connection' do
              subject.connection.expects(:handle_event).never
              subject.handle_ami_event ami_event
            end
          end

          context 'twice' do
            it 'sends a connected event to the event handler' do
              subject.connection.expects(:handle_event).once.with Connection::Connected.new
              subject.handle_ami_event ami_event
              subject.handle_ami_event ami_event
            end
          end
        end

        describe 'with an AsyncAGI Start event' do
          let :ami_event do
            RubyAMI::Event.new('AsyncAGI').tap do |e|
              e['SubEvent'] = "Start"
              e['Channel']  = "SIP/1234-00000000"
              e['Env']      = "agi_request%3A%20async%0Aagi_channel%3A%20SIP%2F1234-00000000%0Aagi_language%3A%20en%0Aagi_type%3A%20SIP%0Aagi_uniqueid%3A%201320835995.0%0Aagi_version%3A%201.8.4.1%0Aagi_callerid%3A%205678%0Aagi_calleridname%3A%20Jane%20Smith%0Aagi_callingpres%3A%200%0Aagi_callingani2%3A%200%0Aagi_callington%3A%200%0Aagi_callingtns%3A%200%0Aagi_dnid%3A%201000%0Aagi_rdnis%3A%20unknown%0Aagi_context%3A%20default%0Aagi_extension%3A%201000%0Aagi_priority%3A%201%0Aagi_enhanced%3A%200.0%0Aagi_accountcode%3A%20%0Aagi_threadid%3A%204366221312%0A%0A"
            end
          end

          before { subject.wrapped_object.stubs :handle_pb_event }

          it 'should be able to look up the call by channel ID' do
            subject.handle_ami_event ami_event
            call_actor = subject.call_for_channel('SIP/1234-00000000')
            call_actor.wrapped_object.should be_a Asterisk::Call
            call_actor.agi_env.should be_a Hash
            call_actor.agi_env[:agi_request].should == 'async'
          end

          it 'should instruct the call to send an offer' do
            mock_call = stub_everything 'Asterisk::Call'
            Asterisk::Call.expects(:new).once.returns mock_call
            mock_call.expects(:send_offer!).once
            subject.handle_ami_event ami_event
          end

          context 'if a call already exists for a matching channel' do
            let(:call) { Asterisk::Call.new "SIP/1234-00000000", subject }

            before do
              subject.register_call call
            end

            it "should not create a new call" do
              Asterisk::Call.expects(:new).never
              subject.handle_ami_event ami_event
            end
          end
        end

        describe 'with a VarSet event including a punchblock_call_id' do
          let :ami_event do
            RubyAMI::Event.new('VarSet').tap do |e|
              e["Privilege"]  = "dialplan,all"
              e["Channel"]    = "SIP/1234-00000000"
              e["Variable"]   = "punchblock_call_id"
              e["Value"]      = call_id
              e["Uniqueid"]   = "1326210224.0"
            end
          end

          before do
            ami_client.stub_everything
            subject.wrapped_object.stubs :handle_pb_event
          end

          context "matching a call that was created by a Dial command" do
            let(:dial_command) { Punchblock::Command::Dial.new :to => 'SIP/1234', :from => 'abc123' }

            before do
              dial_command.request!
              subject.execute_global_command dial_command
              call
            end

            let(:call)    { subject.call_for_channel 'SIP/1234' }
            let(:call_id) { call.id }

            it "should set the correct channel on the call" do
              subject.handle_ami_event ami_event
              call.channel.should == 'SIP/1234-00000000'
            end

            it "should make it possible to look up the call by the full channel name" do
              subject.handle_ami_event ami_event
              subject.call_for_channel("SIP/1234-00000000").should be call
            end

            it "should make looking up the channel by the requested channel name impossible" do
              subject.handle_ami_event ami_event
              subject.call_for_channel('SIP/1234').should be_nil
            end
          end

          context "for a call that doesn't exist" do
            let(:call_id) { 'foobarbaz' }

            it "should not raise" do
              lambda { subject.handle_ami_event ami_event }.should_not raise_error
            end
          end
        end

        describe 'with an AMI event for a known channel' do
          let :ami_event do
            RubyAMI::Event.new('Hangup').tap do |e|
              e['Uniqueid']     = "1320842458.8"
              e['Calleridnum']  = "5678"
              e['Calleridname'] = "Jane Smith"
              e['Cause']        = "0"
              e['Cause-txt']    = "Unknown"
              e['Channel']      = "SIP/1234-00000000"
            end
          end

          let(:call) do
            Asterisk::Call.new "SIP/1234-00000000", subject, "agi_request%3A%20async%0Aagi_channel%3A%20SIP%2F1234-00000000%0Aagi_language%3A%20en%0Aagi_type%3A%20SIP%0Aagi_uniqueid%3A%201320835995.0%0Aagi_version%3A%201.8.4.1%0Aagi_callerid%3A%205678%0Aagi_calleridname%3A%20Jane%20Smith%0Aagi_callingpres%3A%200%0Aagi_callingani2%3A%200%0Aagi_callington%3A%200%0Aagi_callingtns%3A%200%0Aagi_dnid%3A%201000%0Aagi_rdnis%3A%20unknown%0Aagi_context%3A%20default%0Aagi_extension%3A%201000%0Aagi_priority%3A%201%0Aagi_enhanced%3A%200.0%0Aagi_accountcode%3A%20%0Aagi_threadid%3A%204366221312%0A%0A"
          end

          before do
            subject.wrapped_object.stubs :handle_pb_event
            subject.register_call call
          end

          it 'sends the AMI event to the call and to the connection as a PB event' do
            subject.wrapped_object.expects(:handle_pb_event).once
            call.expects(:process_ami_event!).once.with ami_event
            subject.handle_ami_event ami_event
          end
        end
      end

      describe '#send_ami_action' do
        it 'should send the action to the AMI client' do
          ami_client.expects(:send_action).once.with 'foo', :foo => :bar
          subject.send_ami_action 'foo', :foo => :bar
        end
      end
    end
  end
end
