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
      save_localized_attributes
      redefine_build_association
    end

    private

      # Get default options
      def default_options
        {
          except: [], only: [], allow_nil: false, to: [],
          prefix: nil, localized: false, finder: false,
          scope: false, cast: false, define: true
        }
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

      # Get prefixed attribute
      def prefix_attribute(attribute)
        :"#{attribute_prefix}_#{attribute}"
      end

      # Get unprefixed attribute
      def unprefix_attribute(attribute)
        attribute.to_s.sub("#{attribute_prefix}_", '')
      end

      # Get prefixed attributes
      def prefix_attributes(attributes)
        if @options[:prefix].present?
          attributes.map { |a| prefix_attribute(a) }
        else
          attributes
        end
      end

      # Get attribute default
      def attribute_default(attribute)
        @options.fetch :default, association_class.column_defaults["#{attribute}"]
      end

      # Get attribute type from associated model
      def attribute_type(attribute)
        association_class.type_for_attribute("#{attribute}")
      end

      # Get attribute cast type
      def attribute_cast_type(attribute)
        @options.fetch :cast_type, attribute_type(attribute)
      end

      # Check if attribute types are not the same
      def cast_types_mismatch?(attribute)
        attribute_cast_type(attribute) != attribute_type(attribute)
      end

      # Check if attribute needs type cast
      def needs_type_cast?(attribute)
        @options[:cast] != false && cast_types_mismatch?(attribute)
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
      end

      # Save localized attributes in model class
      def save_localized_attributes
        return if @options[:localized].blank?

        lc_method = :"#{dl_atable}_localized_attribute_names"
        localized = prefix_attributes(localized_attributes)
        localized = @model.try(lc_method).to_a.concat(localized)

        @model.send(:define_singleton_method, lc_method) { localized }
      end

      # Define attribute default values, methods and scopes
      def define_attribute_defaults_and_methods(attributes)
        existing  = @model.attribute_names.map(&:to_sym)
        undefined = attributes.reject { |a| a.in? existing }

        undefined.each do |attrib|
          attr_name = unprefix_attribute(attrib)

          define_attribute_default_value(attrib, attr_name)
          define_attribute_type_cast(attrib, attr_name)
          define_attribute_and_alias(attrib, attr_name)
          define_attribute_finders_and_scopes(attrib, attr_name)
        end
      end

      # Define delegated attribute default
      def define_attribute_default_value(attrib, attr_name)
        attr_default = attribute_default(attr_name)

        unless attr_default.nil?
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
      end

      # Define attribute type casting
      def define_attribute_type_cast(attrib, attr_name)
        attr_assoc = @options[:to]
        attr_cattr = :"_attribute_#{attrib}_default"

        if needs_type_cast?(attr_name)
          attr_type = attribute_type(attr_name).type
          cast_type = attribute_cast_type(attr_name)

          redefine_attribute_methods(attrib, attr_name, cast_type, attr_type, attr_assoc, attr_cattr)

          localized_attributes.each do |loc_attr_name|
            loc_attrib = prefix_attribute(loc_attr_name)
            redefine_attribute_methods(loc_attrib, loc_attr_name, cast_type, attr_type, attr_assoc, attr_cattr)
          end
        end
      end

      # Define delegated attribute alias
      def define_attribute_and_alias(attrib, attr_name)
        attr_alias  = @options[:alias]
        attr_define = @options[:define]

        if attr_define
          cast_type = attribute_cast_type(attr_name)
          @model.attribute(attr_alias || attrib, cast_type)
        end

        if attr_alias
          delegatable_methods.each do |method_name|
            old_name = "#{method_name}".sub("#{attr_name}", "#{attrib}")
            new_name = "#{method_name}".sub("#{attr_name}", "#{attr_alias}")

            @model.alias_method :"#{new_name}", :"#{old_name}"
          end
        end
      end

      # Define attribute finders and scopes
      def define_attribute_finders_and_scopes(attrib, attr_name)
        attr_assoc = @options[:to]
        attr_table = association_reflection.klass.table_name
        attr_args  = [@options[:alias] || attrib, attr_name, attr_assoc, attr_table]

        define_attribute_finder_methods(*attr_args) if define_finders?(attr_name)
        define_attribute_scope_methods(*attr_args) if define_scopes?(attr_name)
      end

      # Define attribute finder methods
      def define_attribute_finder_methods(attrib, attr_name, attr_assoc, attr_table)
        @model.send(:define_singleton_method, :"find_by_#{attrib}") do |value|
          joins(attr_assoc).find_by(attr_table => { attr_name => value })
        end

        @model.send(:define_singleton_method, :"find_by_#{attrib}!") do |value|
          joins(attr_assoc).find_by!(attr_table => { attr_name => value })
        end
      end

      # Define attribute scope methods
      def define_attribute_scope_methods(attrib, attr_name, attr_assoc, attr_table)
        @model.send(:define_singleton_method, :"with_#{attrib}") do |*args|
          joins(attr_assoc).where(attr_table => { attr_name => args })
        end

        @model.send(:define_singleton_method, :"without_#{attrib}") do |*args|
          joins(attr_assoc).where.not(attr_table => { attr_name => args })
        end
      end

      # Redefine attribute methods
      def redefine_attribute_methods(attrib, attr_name, cast_type, attr_type, attr_assoc, attr_cattr)
        @model.class_eval do
          class_eval <<-EOM, __FILE__, __LINE__ + 1
            def #{attrib}
              assoc_value = send(:#{attr_assoc}).try(:#{attr_name}) || self.class.try(:#{attr_cattr})
              ActiveRecord::Type.lookup(:#{cast_type}).cast(assoc_value)
            end

            def #{attrib}=(value)
              assoc_value = ActiveRecord::Type.lookup(:#{cast_type}).cast(value)
              assoc_value = ActiveRecord::Type.lookup(:#{attr_type}).cast(assoc_value)
              send(:#{attr_assoc}).send(:#{attr_name}=, assoc_value)
            end
          EOM
        end
      end
  end
end
