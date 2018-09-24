require 'active_delegate/delegator'
require 'active_delegate/attribute/object'
require 'active_delegate/attribute/accessor'

module ActiveDelegate
  class Attributes < Delegator
    # Get default options
    def default_options
      {
        except:    [],
        only:      [],
        localized: false,
        define:    true,
        finder:    false,
        scope:     false,
        to:        nil,
        prefix:    nil,
        allow_nil: false
      }
    end

    # Get attribute options
    def attribute_options
      keys = %i[cast_type default define alias localized finder scope]
      options.select { |k, _v| k.in? keys }.merge(prefix: delegation_prefix)
    end

    # Get association table
    def association_table
      association_class.table_name
    end

    # Default excluded attributes
    def excluded_attributes
      excluded  = %i[id created_at updated_at]
      assoc_as  = association_reflection.options[:as]
      excluded += [:"#{assoc_as}_type", :"#{assoc_as}_id"] if assoc_as.present?

      excluded
    end

    # Get delegatable attributes
    def delegatable_attributes
      attributes  = delegation_args(association_class.attribute_names)
      attributes -= excluded_attributes

      attributes.map! do |attribute_name|
        ActiveDelegate::Attribute::Object.new(
          attribute_name, association_class, attribute_options
        )
      end

      attributes.reject { |a| model.has_attribute?(a.prefixed) }
    end

    # Delegate attributes
    def call
      redefine_build_association(association_name)

      delegatable_attributes.each do |attribute|
        delegate_methods(attribute.delegatable_methods)
        define_model_class_methods(attribute)

        define_attribute_methods(attribute)
        define_attribute_queries(attribute)
      end
    end

    private

    # Redefine build association method
    def redefine_build_association(assoc_name)
      model.class_eval do
        class_eval <<-EOM, __FILE__, __LINE__ + 1
          def #{assoc_name}
            super || send(:build_#{assoc_name})
          end
        EOM
      end
    end

    # Redefine attribute accessor methods
    def redefine_attribute_accessors(method_name, attribute)
      attr_options = {
        association: association_name,
        attribute:   attribute.unprefixed,
        read_type:   attribute.read_type,
        write_type:  attribute.write_type,
        default:     attribute.default
      }

      model.send(:redefine_method, method_name) do |*args|
        ActiveDelegate::Attribute::Accessor.new(self, attr_options).read(*args)
      end

      model.send(:redefine_method, :"#{method_name}=") do |value|
        ActiveDelegate::Attribute::Accessor.new(self, attr_options).write(value)
      end
    end

    # Delegate attribute methods
    def delegate_methods(methods)
      model.delegate(*methods, delegation_options)
    end

    # Define model method keeping old values
    def define_model_method(method, *attributes)
      attributes = model.try(method).to_a.concat(attributes).uniq
      model.send(:define_singleton_method, method) { attributes }
    end

    # Store attribute names in model class methods
    def define_model_class_methods(attribute)
      method_name = :"#{association_table}_attribute_names"
      define_model_method(method_name, attribute.prefixed)

      method_name = :"#{association_table}_localized_attribute_names"
      define_model_method(method_name, attribute.prefixed) if attribute.localized?
    end

    # Define delegated attribute methods
    def define_attribute_methods(attribute)
      if attribute.define?
        model.attribute(attribute.aliased, attribute.read_type)
      end

      attribute.delegatable_attributes.each do |method_name|
        redefine_attribute_accessors(method_name, attribute)
      end

      attribute.aliases.each do |alias_name, method_name|
        model.alias_method(alias_name, method_name)
      end
    end

    # Define attribute finder methods
    def define_attribute_finders(attr_method:, attr_column:, assoc_name:, table_name:)
      model.send(:define_singleton_method, :"find_by_#{attr_method}") do |value|
        joins(assoc_name).find_by(table_name => { attr_column => value })
      end

      model.send(:define_singleton_method, :"find_by_#{attr_method}!") do |value|
        joins(assoc_name).find_by!(table_name => { attr_column => value })
      end
    end

    # Define attribute scope methods
    def define_attribute_scopes(attr_method:, attr_column:, assoc_name:, table_name:)
      model.send(:define_singleton_method, :"with_#{attr_method}") do |*args|
        joins(assoc_name).where(table_name => { attr_column => args })
      end

      model.send(:define_singleton_method, :"without_#{attr_method}") do |*args|
        joins(assoc_name).where.not(table_name => { attr_column => args })
      end
    end

    # Define attribute finders and scopes
    def define_attribute_queries(attribute)
      attr_options = {
        assoc_name:  association_name,
        table_name:  association_table,
        attr_method: attribute.aliased,
        attr_column: attribute.unprefixed
      }

      define_attribute_finders(attr_options) if attribute.finder?
      define_attribute_scopes(attr_options)  if attribute.scope?
    end
  end
end
