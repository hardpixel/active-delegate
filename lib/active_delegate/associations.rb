# frozen_string_literal: true

require 'active_delegate/delegator'
require 'active_delegate/association/methods'

module ActiveDelegate
  # Delegates associations to an associated model
  class Associations < Delegator
    def association_reflections
      association_class.reflect_on_all_associations
    end

    def association_names
      association_reflections.map(&:name)
    end

    def delegatable_associations
      delegation_args(association_names)
    end

    def call
      delegatable_associations.each do |association|
        methods = Association::Methods.new(association, association_class)
        model.delegate(*methods.delegatable, **delegation_options)
      end
    end
  end
end
