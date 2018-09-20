module ActiveDelegate
  module Attribute
    class Methods
      attr_reader :attribute_name, :association_instance

      # Initialize attribute methods
      def initialize(attribute_name, association_class)
        @attribute_name       = attribute_name
        @association_instance = association_class.new
      end

      # Get accessor methods
      def accessors
        suffix_attribute(accessor_suffixes)
      end

      # Get dirty methods for attributes
      def dirty
        suffix_attribute(dirty_suffixes)
      end

      # Get delegatable methods
      def delegatable
        accessors + dirty
      end

      private

      # Get accessor method suffixes
      def accessor_suffixes
        ['', '=', '?']
      end

      # Get dirty method suffixes
      def dirty_suffixes
        @dirty_suffixes ||= Class.new do
          include ::ActiveModel::Dirty
        end.attribute_method_matchers.map(&:suffix).select { |m| m =~ /\A_/ }
      end

      # Generate suffixed array of symbols
      def suffix_attribute(suffixes)
        delegatable = suffixes.map { |s| :"#{attribute_name}#{s}" }
        delegatable & association_instance.methods
      end
    end
  end
end
