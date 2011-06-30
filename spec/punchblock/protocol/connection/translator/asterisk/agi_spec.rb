require 'spec_helper'

module Punchblock
  class Protocol
    module Connection
      module Translator
        class Asterisk
          describe AGI do
            class AGI
              describe CallServer do
                describe "creating an offer from a new call" do
                  let(:connection) { stub :notify_new_call => true, :wire_logger => stub_everything, :event_queue => Queue.new }
                  let(:server) { CallServer.new(mock, connection) }

                  before do
                    CallServer::Variables::Parser.expects(:parse).returns mock(:variables => {:uniqueid => 'abc123', :callerid => '011441234567899', :dnid => '911', :foo => 'bar', :me => 'you'})
                    connection.expects(:notify_new_call).with('abc123', server)
                    server.receive_data "foo: bar\nme:you\n\n"
                  end

                  subject { connection.event_queue.pop true }

                  it { should be_a Event::Offer }
                  its(:call_id) { should == 'abc123' }
                  its(:to) { should == '911' }
                  its(:from) { should == '011441234567899' }
                  its(:headers_hash) { should == {:uniqueid => 'abc123', :callerid => '011441234567899', :dnid => '911', :foo => 'bar', :me => 'you'} }
                end

                it 'should execute the hungup_call event when a HungupExtensionCallException is raised' do
                  pending
                  call_mock = flexmock 'a bogus call', :hungup_call? => true, :variables => {:extension => "h"}, :unique_identifier => "X"
                  mock_env  = flexmock "A mock execution environment which gets passed along in the HungupExtensionCallException"

                  stub_confirmation_manager!
                  flexstub(Adhearsion).should_receive(:receive_call_from).once.and_return(call_mock)
                  flexmock(Adhearsion::DialPlan::Manager).should_receive(:handle).once.and_raise Adhearsion::HungupExtensionCallException.new(mock_env)
                  flexmock(Adhearsion::Events).should_receive(:trigger).once.with([:asterisk, :hungup_call], mock_env).and_throw :hungup_call

                  the_following_code { server.serve nil }.should throw_symbol :hungup_call
                end

                class CallServer
                  module Variables
                    describe Parser do
                      let :typical_call_variable_section do
                        <<-VARIABLES
agi_network: yes
agi_request: agi://10.0.0.152/monkey?foo=bar&qaz=qwerty
agi_channel: SIP/marcel-b58046e0
agi_language: en
agi_type: SIP
agi_uniqueid: 1191245124.16
agi_callerid: 011441234567899
agi_calleridname: unknown
agi_callingpres: 0
agi_callingani2: 0
agi_callington: 0
agi_callingtns: 0
agi_dnid: 911
agi_rdnis: unknown
agi_context: adhearsion
agi_extension: 911
agi_priority: 1
agi_enhanced: 0.0
agi_accountcode:

                        VARIABLES
                      end

                      # TODO:
                      #  - "unknown" should be converted to nil
                      #  - "yes" or "no" should be converted to true or false
                      #  - numbers beginning with a 0 MUST be converted to a NumericalString
                      #  - Look up why there are so many zeroes. They're likely reprentative of some PRI definition.

                      let :typical_call_variables_hash do
                        {
                          :network      => 'yes',
                          :request      => 'agi://10.0.0.152/monkey?foo=bar&qaz=qwerty',
                          :channel      => 'SIP/marcel-b58046e0',
                          :language     => 'en',
                          :type         => 'SIP',
                          :uniqueid     => '1191245124.16',
                          :callerid     => '011441234567899',
                          :calleridname => 'unknown',
                          :callingpres  => '0',
                          :callingani2  => '0',
                          :callington   => '0',
                          :callingtns   => '0',
                          :dnid         => '911',
                          :rdnis        => 'unknown',
                          :context      => 'adhearsion',
                          :extension    => '911',
                          :priority     => '1',
                          :enhanced     => '0.0',
                          :accountcode  => '',
                          :foo          => 'bar',
                          :qaz          => 'qwerty'
                        }
                      end

                      describe 'Typical call variable parsing' do
                        context 'with typical data that has no special treatment' do
                          subject { Parser.parse(typical_call_variable_section.split("\n")).variables }

                          it { should be_a Hash }
                          it { should == typical_call_variables_hash }
                        end
                      end

                      describe '#separate_line_into_key_value_pair' do
                        before do
                          @key, @value = Parser.separate_line_into_key_value_pair line
                        end

                        context 'with a typical line that is not treated specially' do
                          let(:line) { 'agi_channel: SIP/marcel-b58046e0' }

                          it "raw name is extracted correctly" do
                            @key.should == 'agi_channel'
                          end

                          it "raw value is extracted correctly" do
                            @value.should == 'SIP/marcel-b58046e0'
                          end
                        end

                        context 'with a line that is treated specially' do
                          let(:line) { 'agi_request: agi://10.0.0.152' }

                          it "splits out name and value correctly even if the value contains a semicolon (i.e. the same character that is used as the name/value separators)" do
                            @key.should   == 'agi_request'
                            @value.should == 'agi://10.0.0.152'
                          end
                        end

                        context 'with a value containing a space' do
                          let(:line) { "foo: My Name" }

                          it 'retains the space' do
                            @value.should == 'My Name'
                          end
                        end
                      end

                      describe "Extracting the query from the request URI" do
                        subject { Parser.coerce_variables typical_call_variables_hash.merge(:request => "agi://10.0.0.0/?foo=bar&baz=quux&name=marcel") }

                        it "places all key/value pairs in the variables hash" do
                          subject[:foo].should == 'bar'
                          subject[:baz].should == 'quux'
                          subject[:name].should == 'marcel'
                        end
                      end
                    end # Parser
                  end # Variables
                end # CallServer
              end # CallServer
            end # AGI
          end # AGI
        end # Asterisk
      end # Translator
    end # Connection
  end # Protocol
end # Punchblock
