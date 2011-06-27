require 'spec_helper'

module Punchblock
  class Protocol
    module Command
      describe Redirect do

        it 'registers itself' do
          OzoneNode.class_from_registration(:redirect, 'urn:xmpp:ozone:1').should == Redirect
        end

        describe "when setting options in initializer" do
          subject { Redirect.new :to => 'tel:+14045551234', :headers => { :x_skill => 'agent', :x_customer_id => 8877 } }

          it_should_behave_like 'command_headers'

          its(:to) { should == 'tel:+14045551234' }
        end
      end
    end
  end # Protocol
end # Punchblock
