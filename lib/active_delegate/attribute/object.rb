require 'active_delegate/attribute/methods'
require 'active_delegate/attribute/localize'

module ActiveDelegate
  module Attribute
    class Object
      attr_reader :attribute_name, :association_class, :options

      # Initialize attribute methods
      def initialize(attribute_name, association_class, options = {})
        @attribute_name    = attribute_name
        @association_class = association_class
        @options           = options
      end

      # Check if should define attribute
      def define?
        options[:define] || in_option?(:define)
      end

      # Check if should localize attribute
      def localize?
        options[:localized] || in_option?(:localized)
      end

      # Check if should define attribute finders
      def finder?
        options[:finder] || in_option?(:finder)
      end

      # Check if should define attribute scopes
      def scope?
        options[:scope] || in_option?(:scope)
      end

      # Get attribute prefix
      def prefix
        options[:prefix]
      end

      # Get attribute default
      def default
        options.fetch :default, association_class.column_defaults[unprefixed.to_s]
      end

      # Get read type or fallback to write type
      def read_type
        options.fetch :cast_type, write_type
      end

      # Get write type from associated model
      def write_type
        association_class.type_for_attribute(unprefixed.to_s)
      end

      # Get unprefixed attribute
      def unprefixed
        remove_prefix(attribute_name)
      end

      # Get prefixed attribute
      def prefixed
        add_prefix(attribute_name)
      end

      # Check if attribute is prefixed
      def prefixed?
        unprefixed != prefixed
      end

      # Get aliased attribute
      def aliased
        options[:alias] || prefixed
      end

      # Check if attribute is aliased
      def aliased?
        prefixed != aliased
      end

      # Get method aliases
      def aliases
        return {} unless aliased?
        Hash[delegatable_methods.map { |m| generate_alias(m) }]
      end

      # Get localized attributes
      def localized
        @localized ||= Localize.new(unprefixed, association_class).attributes
      end

      # Check if attributes has localized methods
      def localized?
        localized.any?
      end

      # Get delegatable attributes
      def delegatable_attributes
        @delegatable_attributes ||= [unprefixed, *localized].map { |a| add_prefix(a) }
      end

      # Get delegatable attribute methods
      def delegatable_methods
        @delegatable_methods ||= [unprefixed, *localized].flat_map do |method_name|
          Methods.new(method_name, association_class).delegatable
        end
      end

      private

      # Prefix attribute
      def add_prefix(attr_name)
        prefix.present? ? :"#{prefix}_#{attr_name}" : attr_name
      end

      # Unprefix attribute
      def remove_prefix(attr_name)
        attr_name.to_s.sub("#{prefix}_", '').to_sym
      end

      # Generate alias method
      def generate_alias(method_name)
        old_name = method_name.to_s.sub(unprefixed.to_s, prefixed.to_s)
        new_name = method_name.to_s.sub(unprefixed.to_s, aliased.to_s)

        [new_name.to_sym, old_name.to_sym]
      end

      # Check if attribute is in option
      def in_option?(key)
        attribute_name.in? Array(options[key])
      end
    end
  end
end
