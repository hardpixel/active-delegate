module ActiveDelegate
  module Attribute
    class Localize
      attr_reader :attribute_name, :association_instance

      # Initialize attribute methods
      def initialize(attribute_name, association_class)
        @attribute_name       = attribute_name
        @association_instance = association_class.new
      end

      # Get localized attributes
      def attributes
        localized = suffixes.map { |s| :"#{attribute_name}#{s}" }
        localized & association_instance.methods
      end

      private

      # Get localized method suffixes
      def suffixes
        @suffixes ||= I18n.available_locales.map do |locale|
          "_#{normalize_locale(locale)}"
        end
      end

      # Normalize locale
      def normalize_locale(locale)
        locale.to_s.downcase.sub('-', '_').to_s
      end
    end
  end
end
