require 'active_delegate/version'

module ActiveDelegate
  autoload :Associations, 'active_delegate/associations'
  autoload :Attributes,   'active_delegate/attributes'

  require "active_record"

  class << self
    def included(model_class)
      model_class.extend self
    end
  end

  def delegate_associations(*args)
    options = args.extract_options!
    Associations.new(self, options)
  end

  def delegate_attributes(*args)
    options = args.extract_options!
    Attributes.new(self, options)
  end
end
