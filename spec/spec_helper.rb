$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')
$LOAD_PATH.unshift File.dirname(__FILE__)
require 'punchblock'
require 'mocha'
require 'countdownlatch'
require 'logger'

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.mock_with :mocha
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true

  config.before :suite do |variable|
    Punchblock.logger = Logger.new(STDOUT)
  end
end

def parse_stanza(xml)
  Nokogiri::XML.parse xml, nil, nil, Nokogiri::XML::ParseOptions::NOBLANKS
end

def import_stanza(xml)
  Blather::Stanza.import parse_stanza(xml).root
end

# FIXME: change this to rayo_event?  It can be ambigous
shared_examples_for 'event' do
  its(:call_id) { should == '9f00061' }
  its(:component_id) { should == '1' }
end

shared_examples_for 'command_headers' do
  it 'takes a hash of keys and values for headers' do
    headers = { :x_skill => 'agent', :x_customer_id => '8877' }

    control = [ Punchblock::Header.new(:x_skill, 'agent'), Punchblock::Header.new(:x_customer_id, '8877')]

    di = subject.class.new :headers => headers
    di.headers.should have(2).items
    di.headers.each { |i| control.include?(i).should be_true }
  end
end

shared_examples_for 'event_headers' do
  its(:headers) { should == [Punchblock::Header.new(:x_skill, 'agent'), Punchblock::Header.new(:x_customer_id, '8877')]}
  its(:headers_hash) { should == {:x_skill => 'agent', :x_customer_id => '8877'} }
end

shared_examples_for 'key_value_pairs' do
  it 'will auto-inherit nodes' do
    n = parse_stanza "<#{element_name} name='boo' value='bah' />"
    h = class_name.new n.root
    h.name.should == :boo
    h.value.should == 'bah'
  end

  it 'has a name attribute' do
    n = class_name.new :boo, 'bah'
    n.name.should == :boo
    n.name = :foo
    n.name.should == :foo
  end

  it "substitutes - for _ on the name attribute when reading" do
    n = parse_stanza "<#{element_name} name='boo-bah' value='foo' />"
    h = class_name.new n.root
    h.name.should == :boo_bah
  end

  it "substitutes _ for - on the name attribute when writing" do
    h = class_name.new :boo_bah, 'foo'
    h.to_xml.should == "<#{element_name} name=\"boo-bah\" value=\"foo\"/>"
  end

  it 'has a value param' do
    n = class_name.new :boo, 'en'
    n.value.should == 'en'
    n.value = 'de'
    n.value.should == 'de'
  end

  it 'can determine equality' do
    a = class_name.new :boo, 'bah'
    a.should == class_name.new(:boo, 'bah')
    a.should_not == class_name.new(:bah, 'bah')
    a.should_not == class_name.new(:boo, 'boo')
  end
end
