require 'spec_helper'

module Punchblock
  class Protocol
    module Connection
      describe XMPP do
        let(:connection) { XMPP.new :username => 1, :password => 1 }

        subject { connection }

        it 'should require a username and password to be passed in the options' do
          expect { XMPP.new :password => 1 }.to raise_error ArgumentError
          expect { XMPP.new :username => 1 }.to raise_error ArgumentError
        end

        it 'should properly set the Blather logger' do
          XMPP.new :wire_logger => :foo, :username => 1, :password => 1
          Blather.logger.should be :foo
        end

        its(:event_queue) { should be_a Queue }

        it "looking up original command by command ID" do
          call = Punchblock::Call.new '9f00061', 'sip:whatever@127.0.0.1', {}
          say = <<-MSG
  <say xmlns='urn:xmpp:ozone:say:1' voice='allison'>
    <audio url='http://acme.com/greeting.mp3'>
      Thanks for calling ACME company
    </audio>
    <audio url='http://acme.com/package-shipped.mp3'>
      Your package was shipped on
    </audio>
    <say-as interpret-as='date'>12/01/2011</say-as>
  </say>
          MSG
          Command::Say
          say = OzoneNode.import parse_stanza(say).root
          connection.event_queue = []
          connection.expects(:write_to_stream).once.returns true
          iq = Blather::Stanza::Iq.new :set, '9f00061@call.ozone.net'
          connection.expects(:create_iq).returns iq

          write_thread = Thread.new do
            connection.write call, say
          end

          result = import_stanza <<-MSG
  <iq type='result' from='16577@app.ozone.net/1' to='9f00061@call.ozone.net/1' id='#{iq.id}'>
    <ref id='fgh4590' xmlns='urn:xmpp:ozone:1' />
  </iq>
          MSG

          sleep 0.5 # Block so there's enough time for the write thread to get to the point where it's waiting on an IQ

          connection.__send__ :handle_iq_result, result

          write_thread.join

          say.state_name.should == :executing

          connection.original_command_from_id('fgh4590').should == say

          example_complete = import_stanza <<-MSG
  <presence to='16577@app.ozone.net/1' from='9f00061@call.ozone.net/fgh4590'>
    <complete xmlns='urn:xmpp:ozone:ext:1'>
      <success xmlns='urn:xmpp:ozone:say:complete:1' />
    </complete>
  </presence>
          MSG

          connection.__send__ :handle_presence, example_complete
          event = connection.event_queue.last
          event.source.should == say
          say.events.should == [event]

          say.command_id.should == 'fgh4590'
        end

        describe '#handle_presence' do
          let :offer_xml do
            <<-MSG
  <presence to='16577@app.ozone.net/1' from='9f00061@call.ozone.net'>
    <offer xmlns="urn:xmpp:ozone:1" to="sip:whatever@127.0.0.1" from="sip:ylcaomxb@192.168.1.9">
      <header name="Max-Forwards" value="70"/>
      <header name="Content-Length" value="367"/>
    </offer>
  </presence>
            MSG
          end

          let(:example_offer) { import_stanza offer_xml }

          it { example_offer.should be_a Blather::Stanza::Presence }

          let :complete_xml do
            <<-MSG
  <presence to='16577@app.ozone.net/1' from='9f00061@call.ozone.net/fgh4590'>
    <complete xmlns='urn:xmpp:ozone:ext:1'>
      <success xmlns='urn:xmpp:ozone:say:complete:1' />
    </complete>
  </presence>
            MSG
          end

          let(:example_complete) { import_stanza complete_xml }

          it { example_complete.should be_a Blather::Stanza::Presence }

          describe "event placed on the event queue" do
            before do
              connection.event_queue = []
              connection.__send__ :handle_presence, example_offer
              connection.__send__ :handle_presence, example_complete
            end

            describe "from an offer" do
              subject { connection.event_queue.first }

              it { should be_instance_of Call }
              its(:call_id) { should == '9f00061' }

              it "should populate the call map with the domain for the call ID" do
                callmap = connection.instance_variable_get(:'@callmap')
                callmap['9f00061'].should == 'call.ozone.net'
              end
            end

            describe "from a complete" do
              subject { connection.event_queue.last }

              it { should be_instance_of Event::Complete }
              its(:call_id)     { should == '9f00061' }
              its(:connection)  { should == connection }
            end
          end
        end

        describe "#handle_error" do
          let :error_xml do
            <<-MSG
  <iq type="error" id="blather000e" from="f6d437f4-1e18-457b-99f8-b5d853f50347@10.0.1.11/abc123" to="usera@10.0.1.11/voxeo">
    <hangup xmlns="urn:xmpp:ozone:1"/>
    <error type="cancel">
      <item-not-found xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"/>
      <text xmlns="urn:ietf:params:xml:ns:xmpp-stanzas" lang="en">Could not find call [id=f6d437f4-1e18-457b-99f8-b5d853f50347]</text>
    </error>
  </iq>
            MSG
          end

          let(:example_error) { import_stanza error_xml }

          let :receive_error do
            lambda { connection.__send__ :handle_error, example_error }
          end

          let :raised_exception do
            begin
              receive_error.call
            rescue => e
              e
            end
          end

          it "should raise a ProtocolError" do
            receive_error.should raise_error ProtocolError
          end

          subject { raised_exception }

          its(:call_id)     { should == 'f6d437f4-1e18-457b-99f8-b5d853f50347' }
          its(:command_id)  { should == 'abc123' }
          its(:name)        { should == :item_not_found }
          its(:text)        { should == 'Could not find call [id=f6d437f4-1e18-457b-99f8-b5d853f50347]' }
        end
      end # describe XMPP
    end # Connection
  end # Protocol
end # Punchblock
