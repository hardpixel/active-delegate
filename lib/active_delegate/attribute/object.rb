# frozen_string_literal: true

require 'active_delegate/attribute/methods'
require 'active_delegate/attribute/localize'

module ActiveDelegate
  module Attribute
    # Calculates attribute methods, aliases and options
    class Object
      attr_reader :attribute_name, :association_class, :options

      def initialize(attribute_name, association_class, options = {})
        @attribute_name    = attribute_name
        @association_class = association_class
        @options           = options
      end

      def define?
        dirty? && (in_option?(:define) || options[:define])
      end

      def localize?
        in_option?(:localized) || options[:localized]
      end

      def writer?
        in_option?(:writer) || options[:writer]
      end

      def dirty?
        writer? && (in_option?(:dirty) || options[:dirty])
      end

      def finder?
        in_option?(:finder) || options[:finder]
      end

      def scope?
        in_option?(:scope) || options[:scope]
      end

      def prefix
        options[:prefix]
      end

      def default
        options.fetch :default, association_class.column_defaults[unprefixed.to_s]
      end

      def read_type
        options.fetch :cast_type, write_type
      end

      def write_type
        association_class.type_for_attribute(unprefixed.to_s)
      end

      def unprefixed
        remove_prefix(attribute_name)
      end

      def prefixed
        add_prefix(attribute_name)
      end

      def prefixed?
        unprefixed != prefixed
      end

      def aliased
        options[:alias] || prefixed
      end

      def aliased?
        prefixed != aliased
      end

      def aliases
        return {} unless aliased?

        Hash[delegatable_methods.map { |m| generate_alias(m) }]
      end

      def localized
        return [] unless localize?

        @localized ||= Localize.new(unprefixed, association_class).attributes
      end

      def localized?
        localized.any?
      end

      def accessible_attributes
        @accessible_attributes ||= [unprefixed].map { |a| add_prefix(a) }
      end

      def delegatable_attributes
        @delegatable_attributes ||= [unprefixed, *localized].map { |a| add_prefix(a) }
      end

      def delegatable_methods
        @delegatable_methods ||= [unprefixed, *localized].flat_map do |method_name|
          methods = Methods.new(
            method_name, association_class, writer: writer?, dirty: dirty?
          )

          methods.delegatable
        end
      end

      private

      def add_prefix(attr_name)
        prefix.present? ? :"#{prefix}_#{attr_name}" : attr_name
      end

      def remove_prefix(attr_name)
        prefix.present? ? attr_name.to_s.sub("#{prefix}_", '').to_sym : attr_name
      end

      def generate_alias(method_name)
        old_name = method_name.to_s.sub(unprefixed.to_s, prefixed.to_s)
        new_name = method_name.to_s.sub(unprefixed.to_s, aliased.to_s)

        [new_name.to_sym, old_name.to_sym]
      end

      def in_option?(key)
        attribute_name.in? Array(options[key])
      end
    end
  end
end
