# frozen_string_literal: true

module ActiveDelegate
  module Attribute
    # Generates localized attributes names
    class Localize
      attr_reader :attribute_name, :association_instance

      def initialize(attribute_name, association_class)
        @attribute_name       = attribute_name
        @association_instance = association_class.new
      end

      def attributes
        localized = suffixes.map { |s| :"#{attribute_name}#{s}" }
        localized & association_instance.methods
      end

      private

      def suffixes
        @suffixes ||= I18n.available_locales.map do |locale|
          "_#{normalize_locale(locale)}"
        end
      end

      def normalize_locale(locale)
        locale.to_s.downcase.sub('-', '_').to_s
      end
    end
  end
end
