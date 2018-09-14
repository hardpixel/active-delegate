module ActiveDelegate
  module Methods
    module Accessor
      class << self
        # Get accessor methods for attributes
        def for(attributes)
          @accessor_methods = Array(attributes).flat_map do |attribute|
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
end
