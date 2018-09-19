module ActiveDelegate
  class Delegator
    attr_reader :model, :options

    # Initialize delegator
    def initialize(model, options)
      @model   = model
      @options = default_options.merge(options.symbolize_keys)
    end

    # Get default options
    def default_options
      {
        except:    [],
        only:      [],
        to:        nil,
        allow_nil: false
      }
    end

    # Get delegation options
    def delegation_options
      options.select { |k, _v| k.in? [:to, :allow_nil, :prefix] }
    end

    # Get delegation arguments
    def delegation_args(available=[])
      included  = Array(options[:only]).map(&:to_sym)
      excluded  = Array(options[:except]).map(&:to_sym)
      available = Array(available).map(&:to_sym)
      available = available & included if included.any?
      available = available - excluded if excluded.any?

      available
    end

    # Get delegation prefix
    def delegation_prefix
      prefix = options[:prefix]
      prefix == true ? association_name : prefix
    end

    # Get association name
    def association_name
      @options[:to]
    end

    # Get association reflection
    def association_reflection
      reflection = @model.reflect_on_association(association_name)
      return reflection unless reflection.nil?
      raise "#{@model.name} don't have the association #{association_name}"
    end

    # Get model association class
    def association_class
      association_reflection.klass
    end
  end
end
