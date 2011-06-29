module Punchblock
  class Protocol
    module Connection
      class Asterisk
        class Call < Punchblock::Call
          module Variables
            module Coercions
              COERCION_ORDER = %w{
                remove_agi_prefixes_from_keys_and_strip_whitespace
                coerce_keys_into_symbols
                decompose_uri_query_into_hash
                override_variables_with_query_params
                remove_dashes_from_context_name
              }

              class << self
                def remove_agi_prefixes_from_keys_and_strip_whitespace(variables)
                  variables.inject({}) do |new_variables,(key,value)|
                    new_variables.tap do
                      stripped_name = key.kind_of?(String) ? key[/^(agi_)?(.+)$/,2] : key
                      new_variables[stripped_name] = value.kind_of?(String) ? value.strip : value
                    end
                  end
                end

                def coerce_keys_into_symbols(variables)
                  variables.inject({}) do |new_variables,(key,value)|
                    new_variables.tap do
                      new_variables[key.to_sym] = value
                    end
                  end
                end

                def decompose_uri_query_into_hash(variables)
                  variables.tap do
                    request = URI.parse variables[:request]
                    if request && request.query
                      request.query.split('&').each do |key_value_pair|
                        parameter_name, parameter_value = *key_value_pair.match(/(.+)=(.*)/).captures
                        variables[:"#{parameter_name}"] = parameter_value
                      end
                    end
                  end
                end

                def override_variables_with_query_params(variables)
                  variables.tap do
                    if variables[:query]
                      variables[:query].each do |key, value|
                        variables[key.to_sym] = value
                      end
                    end
                  end
                end

                def remove_dashes_from_context_name(variables)
                  variables.tap { variables[:context].gsub! '-', '_' if variables[:context] }
                end
              end
            end # Coercions

            class Parser
              class << self
                def parse(*args, &block)
                  new(*args, &block).tap { |parser| parser.parse }
                end

                def coerce_variables(variables)
                  Coercions::COERCION_ORDER.inject variables do |tmp_variables, coercing_method_name|
                    Coercions.send coercing_method_name, tmp_variables
                  end
                end

                def separate_line_into_key_value_pair(line)
                  line.match(/^([^:]+):(?:\s?(.+)|$)/).captures
                end
              end

              attr_reader :variables, :lines

              def initialize(lines = [])
                @lines = lines
              end

              def parse
                initialize_variables_as_hash_from_lines
                @variables = self.class.coerce_variables variables
              end

              private

                def initialize_variables_as_hash_from_lines
                  @variables = lines.inject({}) do |new_variables,line|
                    new_variables.tap do
                      key, value = self.class.separate_line_into_key_value_pair line
                      new_variables[key] = value || ''
                    end
                  end
                end
            end # Parser
          end # Variables
        end # Call
      end # Asterisk
    end # Connection
  end # Protocol
end # Punchblock
