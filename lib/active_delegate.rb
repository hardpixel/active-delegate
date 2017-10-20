require 'active_record'
require 'active_delegate/version'

module ActiveDelegate
  extend ActiveSupport::Concern

  # Autoload modules
  autoload :Associations, 'active_delegate/associations'
  autoload :Attributes,   'active_delegate/attributes'

  class_methods do
    # Delegate associations
    def delegate_associations(*args)
      options = args.extract_options!
      Associations.new(self, options)
    end

    # Delegate attributes
    def delegate_attributes(*args)
      options = args.extract_options!
      Attributes.new(self, options)
    end
  end
end
