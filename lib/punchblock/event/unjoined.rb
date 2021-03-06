module Punchblock
  class Event
    class Unjoined < Event
      register :unjoined, :core

      ##
      # @return [String] the call ID that was unjoined
      def other_call_id
        read_attr :'call-id'
      end

      ##
      # @param [String] other the call ID that was unjoined
      def other_call_id=(other)
        write_attr :'call-id', other
      end

      ##
      # @return [String] the mixer name that was unjoined
      def mixer_name
        read_attr :'mixer-name'
      end

      ##
      # @param [String] other the mixer name that was unjoined
      def mixer_name=(other)
        write_attr :'mixer-name', other
      end

      def inspect_attributes # :nodoc:
        [:other_call_id, :mixer_name] + super
      end
    end # Unjoined
  end
end # Punchblock
