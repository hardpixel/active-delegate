# frozen_string_literal: true

require 'active_delegate/delegator'
require 'active_delegate/attribute/object'
require 'active_delegate/attribute/accessor'

module ActiveDelegate
  # Delegates attributes to an associated model
  class Attributes < Delegator
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

    def attribute_options
      keys = %i[cast_type default define alias localized finder scope]
      options.select { |k, _v| k.in? keys }.merge(prefix: delegation_prefix)
    end

    def association_table
      association_class.table_name
    end

    def excluded_attributes
      excluded  = %i[created_at updated_at]
      excluded << association_reflection.active_record_primary_key.to_sym

      for_key   = association_reflection.foreign_key
      excluded << for_key.to_sym if for_key.present?

      sti_col   = association_class.inheritance_column
      excluded << sti_col.to_sym if sti_col.present?

      assoc_as  = association_reflection.options[:as]
      excluded += [:"#{assoc_as}_type", :"#{assoc_as}_id"] if assoc_as.present?

      excluded
    end

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

    def redefine_build_association(assoc_name)
      model.class_eval do
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{assoc_name}
            super || send(:build_#{assoc_name})
          end
        RUBY
      end
    end

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

    def delegate_methods(methods)
      model.delegate(*methods, delegation_options)
    end

    def define_model_method(method, *attributes)
      attributes = model.try(method).to_a.concat(attributes).uniq
      model.send(:define_singleton_method, method) { attributes }
    end

    def define_model_class_methods(attribute)
      method_name = :"#{association_table}_attribute_names"
      define_model_method(method_name, attribute.prefixed)

      method_name = :"#{association_table}_localized_attribute_names"
      define_model_method(method_name, attribute.prefixed) if attribute.localized?
    end

    def define_attribute_methods(attribute)
      model.attribute(attribute.aliased, attribute.read_type) if attribute.define?

      attribute.delegatable_attributes.each do |method_name|
        redefine_attribute_accessors(method_name, attribute)
      end

      attribute.aliases.each do |alias_name, method_name|
        model.alias_method(alias_name, method_name)
      end
    end

    def define_attribute_finders(attr_method:, attr_column:, assoc_name:, table_name:)
      model.send(:define_singleton_method, :"find_by_#{attr_method}") do |value|
        joins(assoc_name).find_by(table_name => { attr_column => value })
      end

      model.send(:define_singleton_method, :"find_by_#{attr_method}!") do |value|
        joins(assoc_name).find_by!(table_name => { attr_column => value })
      end
    end

    def define_attribute_scopes(attr_method:, attr_column:, assoc_name:, table_name:)
      model.send(:define_singleton_method, :"with_#{attr_method}") do |*args|
        joins(assoc_name).where(table_name => { attr_column => args })
      end

      model.send(:define_singleton_method, :"without_#{attr_method}") do |*args|
        joins(assoc_name).where.not(table_name => { attr_column => args })
      end
    end

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
