module ActiveDelegate
  module ReadWrite
    class << self
      # Get readwrite methods for attributes
      def readwrite_methods(attributes)
        @readwrite_methods = attributes.to_a.flat_map do |attribute|
          method_suffixes.map { |suffix| "#{attribute}#{suffix}" }
        end
      end

      # Get method suffixes
      def method_suffixes
        ['', '=', '?']
      end
    end
  end
end
