# frozen_string_literal: true

module ActiveDelegate
  # Validates delegation target and sets basic options
  class Delegator
    attr_reader :model, :options

    def initialize(model, options)
      @model   = model
      @options = default_options.merge(options.symbolize_keys)
    end

    def default_options
      {
        except:    [],
        only:      [],
        to:        nil,
        allow_nil: false
      }
    end

    def delegation_options
      options.select { |k, _v| k.in? %i[to allow_nil prefix] }
    end

    def delegation_args(available = [])
      included   = Array(options[:only]).map(&:to_sym)
      excluded   = Array(options[:except]).map(&:to_sym)
      available  = Array(available).map(&:to_sym)
      available &= included if included.any?
      available -= excluded if excluded.any?

      available
    end

    def delegation_prefix
      prefix = options[:prefix]
      prefix == true ? association_name : prefix
    end

    def association_name
      @options[:to]
    end

    def association_reflection
      reflection = model.reflect_on_association(association_name)
      return reflection unless reflection.nil?

      raise "#{model.name} don't have the association #{association_name}"
    end

    def association_class
      association_reflection.klass
    end
  end
end
