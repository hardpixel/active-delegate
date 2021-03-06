# frozen_string_literal: true

module ActiveDelegate
  module Attribute
    # Generates attribute method names
    class Methods
      attr_reader :attribute_name, :association_instance

      def initialize(attribute_name, association_class, writer:, dirty:)
        @define_writer        = writer
        @define_dirty         = dirty
        @attribute_name       = attribute_name
        @association_instance = association_class.new
      end

      def accessors
        suffix_attribute(accessor_suffixes)
      end

      def dirty
        suffix_attribute(dirty_suffixes)
      end

      def delegatable
        accessors + dirty
      end

      private

      def accessor_suffixes
        suffixes = ['', '?']
        suffixes << '=' if @define_writer

        suffixes
      end

      def dirty_module
        @dirty_module ||= Class.new do
          include ::ActiveModel::Dirty
        end
      end

      def dirty_suffixes
        return [] unless @define_dirty

        @dirty_suffixes ||= begin
          suffixes = dirty_module.attribute_method_matchers.map(&:suffix)
          suffixes.select { |m| m.starts_with?('_') }
        end
      end

      def suffix_attribute(suffixes)
        delegatable = suffixes.map { |s| :"#{attribute_name}#{s}" }
        delegatable & association_instance.methods
      end
    end
  end
end
