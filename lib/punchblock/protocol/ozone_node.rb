require 'active_support/core_ext/class/inheritable_attributes'

module Punchblock
  class Protocol
    autoload :Niceogiri,  'niceogiri'
    autoload :Nokogiri,   'nokogiri'

    class OzoneNode < Niceogiri::XML::Node
      @@registrations = {}

      class_inheritable_accessor :registered_ns, :registered_name

      attr_accessor :call_id, :command_id, :connection, :original_command

      # Register a new stanza class to a name and/or namespace
      #
      # This registers a namespace that is used when looking
      # up the class name of the object to instantiate when a new
      # stanza is received
      #
      # @param [#to_s] name the name of the node
      # @param [String, nil] ns the namespace the node belongs to
      def self.register(name, ns = nil)
        self.registered_name = name.to_s
        self.registered_ns = ns.is_a?(Symbol) ? OZONE_NAMESPACES[ns] : ns
        @@registrations[[self.registered_name, self.registered_ns]] = self
      end

      # Find the class to use given the name and namespace of a stanza
      #
      # @param [#to_s] name the name to lookup
      # @param [String, nil] xmlns the namespace the node belongs to
      # @return [Class, nil] the class appropriate for the name/ns combination
      def self.class_from_registration(name, ns = nil)
        @@registrations[[name.to_s, ns]]
      end

      # Import an XML::Node to the appropriate class
      #
      # Looks up the class the node should be then creates it based on the
      # elements of the XML::Node
      # @param [XML::Node] node the node to import
      # @return the appropriate object based on the node name and namespace
      def self.import(node, call_id = nil, command_id = nil)
        ns = (node.namespace.href if node.namespace)
        klass = class_from_registration(node.element_name, ns)
        event = if klass && klass != self
          klass.import node, call_id, command_id
        else
          new(node.element_name).inherit node
        end
        event.tap do |event|
          event.call_id = call_id
          event.command_id = command_id
        end
      end

      # Create a new Node object
      #
      # @param [String, nil] name the element name
      # @param [XML::Document, nil] doc the document to attach the node to. If
      # not provided one will be created
      # @return a new object with the registered name and namespace
      def self.new(name = registered_name, doc = nil)
        super name, doc, registered_ns
      end

      def inspect_attributes # :nodoc:
        [:call_id, :command_id, :namespace_href]
      end

      def inspect
        "#<#{self.class} #{inspect_attributes.map { |c| "#{c}=#{self.__send__(c).inspect}" rescue nil }.compact * ', '}>"
      end

      ##
      # @return [OzoneNode] the original command issued that lead to this event
      #
      def source
        @source ||= original_command
        @source ||= connection.original_command_from_id command_id if connection && command_id
      end

      alias :to_s :inspect
      alias :xmlns :namespace_href
    end
  end
end
