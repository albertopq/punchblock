require 'spec_helper'

module Punchblock
  class Protocol
    module Connection
      class Asterisk
        module CallVariableTestHelper
          def parsed_call_variables_from(lines)
            Call::Variables::Parser.parse(lines).variables
          end

          def coerce_call_variables(variables)
            Call::Variables::Parser.coerce_variables variables
          end

          def merged_hash_with_call_variables(new_hash)
            call_variables_with_new_query = typical_call_variables_hash.merge new_hash
            coerce_call_variables call_variables_with_new_query
          end

          def parsed_call_variables_with_query(query_string)
            merged_hash_with_call_variables :request => "agi://10.0.0.0/#{query_string}"
          end

          def typical_call_variable_lines
            typical_call_variable_section.split "\n"
          end

          def typical_call_variable_section
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

          def typical_call_variables_hash
            expected_uncoerced_variable_map.tap do |typical|
              typical[:foo] = 'bar'
              typical[:qaz] = 'qwerty'
            end
          end

          def expected_uncoerced_variable_map
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
              :accountcode  => ''
            }
          end
        end

        class Call
          module Variables
            describe Parser do
              include CallVariableTestHelper

              describe 'Typical call variable parsing' do
                context 'with typical data that has no special treatment' do
                  subject { parsed_call_variables_from typical_call_variable_lines }

                  it { should be_a Hash }
                  it { should == typical_call_variables_hash }
                end

                describe '#separate_line_into_key_value_pair' do
                  it 'parses values with spaces in them' do
                    key, value = Parser.separate_line_into_key_value_pair "foo: My Name"
                    value.should == 'My Name'
                  end
                end
              end

              describe 'call variable line parsing' do
                context 'with a typical line that is not treated specially' do
                  let(:line) { 'agi_channel: SIP/marcel-b58046e0' }

                  before do
                    @key, @value = Parser.separate_line_into_key_value_pair line
                  end

                  it "raw name is extracted correctly" do
                    @key.should == 'agi_channel'
                  end

                  it "raw value is extracted correctly" do
                    @value.should == 'SIP/marcel-b58046e0'
                  end
                end

                context 'with a line that is treated specially' do
                  let(:line) { 'agi_request: agi://10.0.0.152' }

                  before do
                    @key, @value = Parser.separate_line_into_key_value_pair line
                  end

                  it "splits out name and value correctly even if the value contains a semicolon (i.e. the same character that is used as the name/value separators)" do
                    @key.should   == 'agi_request'
                    @value.should == 'agi://10.0.0.152'
                  end
                end
              end

              describe "Extracting the query from the request URI" do
                subject { parsed_call_variables_with_query '?foo=bar&baz=quux&name=marcel' }

                it "all key/value pairs are returned when there are more than a pair of query string parameters" do
                  subject[:foo].should == 'bar'
                  subject[:baz].should == 'quux'
                  subject[:name].should == 'marcel'
                end
              end
            end # Parser
          end # Variables
        end # Call
      end # Asterisk
    end # Connection
  end # Protocol
end # Punchblock
