# frozen_string_literal: true

module ActiveDelegate
  module Association
    # Generates association method names
    class Methods
      attr_reader :association_name, :association_class

      def initialize(association_name, association_class)
        @association_name  = association_name
        @association_class = association_class
      end

      def delegatable
        delegatable = suffixed + prefixed
        delegatable & association_class.instance_methods
      end

      private

      def prefixes
        ['build_']
      end

      def suffixes
        ['', '=', '_attributes', '_attributes=']
      end

      def prefixed
        prefixes.map { |s| :"#{s}#{association_name}" }
      end

      def suffixed
        suffixes.map { |s| :"#{association_name}#{s}" }
      end
    end
  end
end
