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
      options = options.reverse_merge(only: args)

      Associations.new(self, options).call
    end

    # Delegate association
    def delegate_association(association, options={})
      options = options.merge(only: association)
      Associations.new(self, options).call
    end

    # Delegate attributes
    def delegate_attributes(*args)
      options = args.extract_options!
      options = options.except(:single, :cast_type, :alias)

      Attributes.new(self, options)
    end

    # Delegate attribute
    def delegate_attribute(attribute, cast_type, options={})
      options = options.except(:only, :except)
      options = options.merge(only: [attribute], single: true, cast_type: cast_type)

      Attributes.new(self, options)
    end
  end
end
