module ActiveDelegate
  autoload :ReadWrite, 'active_delegate/read_write'
  autoload :Dirty,     'active_delegate/dirty'
  autoload :Localized, 'active_delegate/localized'

  class Attributes
    # Initialize attributes
    def initialize(model, attributes, options)
      @model      = model
      @attributes = attributes
      @options    = default_options.merge(options)

      delegate_attributes
      save_delegated_attributes
      build_association
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
        association_reflection.try :klass
      end

      # Get association attribute names
      def association_attribute_names
        association_class.try(:attribute_names) || []
      end

      # Default excluded attributes
      def default_excluded_attributes
        assoc_as  = association_reflection.options[:as]
        poly_attr = [:"#{assoc_as}_type", :"#{assoc_as}_id"] if assoc_as.present?

        [:id, :created_at, :updated_at] + poly_attr.to_a
      end

      # Get delegatable attributes
      def delegatable_attributes
        attributes = association_attribute_names.map(&:to_sym)
        attributes = attributes & @options[:only].to_a   if @options[:only].present?
        attributes = attributes - @options[:except].to_a if @options[:except].present?
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

      # Build association method override
      def build_association
        @model.class.send :define_method, :"#{@options[:to]}" do
          super || @model.send(:"build_#{@options[:to]}")
        end
      end

      # Get prefixed attributes
      def prefix_attributes(attributes)
        if @options[:prefix].present?
          attributes.map { |a| :"#{@options[:prefix]}_#{a}" }
        else
          attributes
        end
      end

      # Save delagated attributes in model class
      def save_delegated_attributes
        delegated = prefix_attributes(delegatable_attributes)
        @model.send :define_singleton_method, :"#{@options[:to]}_attribute_names" do
          delegated
        end

        if @options[:localized].present?
          localized = prefix_attributes(localized_attributes)
          @model.send :define_singleton_method, :"#{@options[:to]}_localized_attribute_names" do
            localized
          end
        end
      end
  end
end
