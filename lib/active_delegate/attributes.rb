module ActiveDelegate
  autoload :ReadWrite, 'active_delegate/read_write'
  autoload :Dirty,     'active_delegate/dirty'
  autoload :Localized, 'active_delegate/localized'

  class Attributes
    # Initialize attributes
    def initialize(model, options)
      @model   = model
      @options = default_options.merge(options)

      delegate_attributes
      save_delegated_attributes
      redefine_build_association
    end

    private

      # Get default options
      def default_options
        { except: [], only: [], allow_nil: false, to: [], prefix: nil, localized: false }
      end

      # Get association reflection
      def association_reflection
        assoc_name = @options.fetch(:to)
        reflection = @model.reflect_on_association(assoc_name)

        return reflection unless reflection.nil?
        raise "#{@model.name} don't have the association #{assoc_name}"
      end

      # Get model association class
      def association_class
        association_reflection.klass
      end

      # Get association attribute names
      def association_attribute_names
        association_class.attribute_names
      end

      # Default excluded attributes
      def default_excluded_attributes
        assoc_as  = association_reflection.options[:as]
        poly_attr = [:"#{assoc_as}_type", :"#{assoc_as}_id"] if assoc_as.present?

        [:id, :created_at, :updated_at] + poly_attr.to_a
      end

      # Get method attributes
      def association_valid_methods(attributes)
        assoc_methods = association_class.public_instance_methods
        attributes.to_a.select { |a| a.in? assoc_methods }
      end

      # Get delegatable attributes
      def delegatable_attributes
        attributes = association_attribute_names.map(&:to_sym)
        attributes = attributes & @options[:only].to_a   if @options[:only].present?
        attributes = attributes - @options[:except].to_a if @options[:except].present?
        attributes = attributes + association_valid_methods(@options[:only])
        attributes = attributes - default_excluded_attributes

        attributes.map(&:to_sym)
      end

      # Get localized delegatable attributes
      def localized_attributes
        attributes = delegatable_attributes
        localized  = Localized.localized_methods(attributes) if @options[:localized].present?

        localized.to_a.map(&:to_sym)
      end

      # Get delegatable methods
      def delegatable_methods
        attributes = delegatable_attributes + localized_attributes
        readwrite  = ReadWrite.readwrite_methods(attributes)
        dirty      = Dirty.dirty_methods(attributes)
        methods    = readwrite + dirty

        methods.map(&:to_sym)
      end

      # Delegate attributes
      def delegate_attributes
        options = { to: @options[:to], allow_nil: @options[:allow_nil], prefix: @options[:prefix] }
        @model.delegate(*delegatable_methods, options)
      end

      # Redefine build association method
      def redefine_build_association
        assoc_name = @options[:to]

        @model.class_eval do
          class_eval <<-EOM, __FILE__, __LINE__ + 1
            def #{assoc_name}
              super || send(:build_#{assoc_name})
            end
          EOM
        end
      end

      # Get prefixed attributes
      def prefix_attributes(attributes)
        if @options[:prefix].present?
          prefix = @options[:prefix]
          prefix = @options[:to] if prefix.is_a? TrueClass

          attributes.map { |a| :"#{prefix}_#{a}" }
        else
          attributes
        end
      end

      # Save delagated attributes in model class
      def save_delegated_attributes
        dl_method = :"#{@options[:to]}_attribute_names"
        delegated = prefix_attributes(delegatable_attributes)
        delegated = @model.try(dl_method).to_a.concat(delegated)

        @model.send(:define_singleton_method, dl_method) { delegated }

        if @options[:localized].present?
          localized = prefix_attributes(localized_attributes)
          lc_method = :"#{@options[:to]}_localized_attribute_names"

          @model.send(:define_singleton_method, lc_method) { localized }
        end
      end
  end
end
