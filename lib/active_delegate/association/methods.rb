module ActiveDelegate
  module Association
    class Methods
      attr_reader :association_name, :association_class

      # Initialize association methods
      def initialize(association_name, association_class)
        @association_name  = association_name
        @association_class = association_class
      end

      # Get delegatable methods
      def delegatable
        delegatable = suffixed + prefixed
        delegatable & association_class.instance_methods
      end

      private

      # Get method prefixes
      def prefixes
        ['build_']
      end

      # Get method suffixes
      def suffixes
        ['', '=', '_attributes', '_attributes=']
      end

      # Get prefixed methods
      def prefixed
        prefixes.map { |s| :"#{s}#{attribute}" }
      end

      # Get suffixed methods
      def suffixed
        suffixes.map { |s| :"#{attribute}#{s}" }
      end
    end
  end
end
