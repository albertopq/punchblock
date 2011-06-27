module Punchblock
  class Protocol
    module Event
      class Offer < OzoneNode
        register :offer, :core

        include HasHeaders

        def to
          read_attr :to
        end

        def to=(offer_to)
          write_attr :to, offer_to
        end

        def from
          read_attr :from
        end

        def from=(offer_from)
          write_attr :from, offer_from
        end

        def inspect_attributes # :nodoc:
          [:to, :from] + super
        end
      end # Offer
    end # Event
  end # Protocol
end # Punchblock
