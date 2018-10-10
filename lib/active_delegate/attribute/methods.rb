# frozen_string_literal: true

module ActiveDelegate
  module Attribute
    # Generates attribute method names
    class Methods
      attr_reader :attribute_name, :association_instance

      def initialize(attribute_name, association_class)
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
        ['', '=', '?']
      end

      def dirty_suffixes
        @dirty_suffixes ||= Class.new do
          include ::ActiveModel::Dirty
        end.attribute_method_matchers.map(&:suffix).select { |m| m =~ /\A_/ }
      end

      def suffix_attribute(suffixes)
        delegatable = suffixes.map { |s| :"#{attribute_name}#{s}" }
        delegatable & association_instance.methods
      end
    end
  end
end
