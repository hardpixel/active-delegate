module ActiveDelegate
  module Association
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
        prefixes.map { |s| :"#{s}#{attribute}" }
      end

      def suffixed
        suffixes.map { |s| :"#{attribute}#{s}" }
      end
    end
  end
end
