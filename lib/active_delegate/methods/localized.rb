require 'i18n'

module ActiveDelegate
  module Methods
    module Localized
      class << self
        # Get localized methods for attributes
        def for(attributes)
          @localized_methods = Array(attributes).flat_map do |attribute|
            method_suffixes.map { |suffix| "#{attribute}#{suffix}" }
          end
        end

        # Get method suffixes
        def method_suffixes
          @method_suffixes ||= I18n.available_locales.map do |locale|
            "_#{normalize_locale(locale)}"
          end
        end

        # Normalize locale
        def normalize_locale(locale)
          "#{locale.to_s.downcase.sub("-", "_")}".freeze
        end
      end
    end
  end
end
