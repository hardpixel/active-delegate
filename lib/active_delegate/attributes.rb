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
        { except: [], only: [], allow_nil: false, to: [], prefix: nil, localized: false, finder: false, scope: false }
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

      # Get attribute prefix
      def attribute_prefix
        prefix = @options[:prefix]
        prefix.is_a?(TrueClass) ? @options[:to] : prefix
      end

      # Get unprefixed attribute
      def unprefix_attribute(attribute)
        attribute.to_s.sub("#{attribute_prefix}_", '')
      end

      # Get prefixed attributes
      def prefix_attributes(attributes)
        if @options[:prefix].present?
          attributes.map { |a| :"#{attribute_prefix}_#{a}" }
        else
          attributes
        end
      end

      # Get attribute default
      def attribute_default(attribute)
        @options[:default] || association_class.column_defaults["#{attribute}"]
      end

      # Get attribute cast type
      def attribute_cast_type(attribute)
        @options[:cast_type] || association_class.attribute_types["#{attribute}"]
      end

      # Check if should define attribute finders
      def define_finders?(attribute)
        @options[:finder] || Array(@options[:finder]).include?(attribute)
      end

      # Check if should define attribute scopes
      def define_scopes?(attribute)
        @options[:scope] || Array(@options[:scope]).include?(attribute)
      end

      # Save delagated attributes in model class
      def save_delegated_attributes
        dl_atable = association_reflection.klass.table_name
        dl_method = :"#{dl_atable}_attribute_names"

        delegated = prefix_attributes(delegatable_attributes)
        define_attribute_defaults_and_methods(delegated)

        delegated = @model.try(dl_method).to_a.concat(delegated)
        @model.send(:define_singleton_method, dl_method) { delegated }

        if @options[:localized].present?
          localized = prefix_attributes(localized_attributes)
          lc_method = :"#{dl_atable}_localized_attribute_names"

          @model.send(:define_singleton_method, lc_method) { localized }
        end
      end

      # Define attribute default values, methods and scopes
      def define_attribute_defaults_and_methods(attributes)
        existing  = @model.attribute_names.map(&:to_sym)
        undefined = attributes.reject { |a| a.in? existing }

        undefined.each do |attrib|
          attr_name    = attrib.to_s.sub("#{attribute_prefix}_", '')
          cast_type    = @options[:cast_type] || association_class.attribute_types["#{attr_name}"]
          attr_alias   = @options[:alias]
          attr_default = @options[:default] || association_class.column_defaults["#{attr_name}"]
          attr_finder  = @options[:finder] || Array(@options[:finder]).include?(attr_name)
          attr_scope   = @options[:scope] || Array(@options[:scope]).include?(attr_name)

          @model.attribute(attrib, cast_type)

          define_attribute_default_value(attrib, attr_name, attr_default) unless attr_default.nil?
          define_attribute_alias_method(attrib, attr_alias, cast_type) unless attr_alias.nil?
          define_attribute_finder_methods(attr_alias || attrib, attr_name) if attr_finder == true
          define_attribute_scope_methods(attr_alias || attrib, attr_name) if attr_scope == true
        end
      end

      # Define delegated attribute default
      def define_attribute_default_value(attrib, attr_name, attr_default)
        attr_assoc = @options[:to]
        attr_cattr = :"_attribute_#{attrib}_default"

        @model.send(:define_singleton_method, attr_cattr) { attr_default }

        @model.class_eval do
          class_eval <<-EOM, __FILE__, __LINE__ + 1
            def #{attrib}
              send(:#{attr_assoc}).try(:#{attr_name}) || self.class.send(:#{attr_cattr})
            end
          EOM
        end
      end

      # Define delegated attribute alias
      def define_attribute_alias_method(attrib, attr_alias, cast_type)
        @model.attribute(attr_alias, cast_type)
        @model.alias_attribute(attr_alias, attrib)
      end

      # Define attribute finder methods
      def define_attribute_finder_methods(attrib, attr_name)
        attr_assoc  = @options[:to]
        attr_table  = association_reflection.klass.table_name
        attr_method = :"find_by_#{attrib}"

        @model.send(:define_singleton_method, attr_method) do |value|
          value = type_caster.type_cast_for_database(attr_name, value)
          joins(attr_assoc).find_by(attr_table => { attr_name => value })
        end

        @model.send(:define_singleton_method, :"#{attr_method}!") do |value|
          value = type_caster.type_cast_for_database(attr_name, value)
          joins(attr_assoc).find_by!(attr_table => { attr_name => value })
        end
      end

      # Define attribute scope methods
      def define_attribute_scope_methods(attrib, attr_name)
        attr_assoc = @options[:to]
        attr_table = association_reflection.klass.table_name

        @model.scope :"with_#{attrib}", -> (*names) do
          names = names.map { |n| type_caster.type_cast_for_database(attr_name, n) }
          joins(attr_assoc).where(attr_table => { attr_name => names })
        end

        @model.scope :"without_#{attrib}", -> (*names) do
          names = names.map { |n| type_caster.type_cast_for_database(attr_name, n) }
          joins(attr_assoc).where.not(attr_table => { attr_name => names })
        end
      end
  end
end
