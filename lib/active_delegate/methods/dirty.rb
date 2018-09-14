module ActiveDelegate
  module Methods
    module Dirty
      class << self
        # Get dirty methods for attributes
        def for(attributes)
          @dirty_methods = Array(attributes).flat_map do |attribute|
            method_suffixes.map { |suffix| "#{attribute}#{suffix}" }
          end
        end

        # Get method suffixes
        def method_suffixes
          @method_suffixes ||= Class.new do
            include ::ActiveModel::Dirty
          end.attribute_method_matchers.map(&:suffix).select { |m| m =~ /\A_/ }
        end
      end
    end
  end
end