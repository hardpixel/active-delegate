require 'active_delegate/association/methods'

module ActiveDelegate
  class Associations < Delegator
    # Get all associations
    def association_reflections
      association_class.reflect_on_all_associations
    end

    # Get singular model association names
    def association_names
      association_reflections.map(&:name)
    end

    # Get delegatable associations
    def delegatable_associations
      delegation_args(association_names)
    end

    # Delegate associations
    def call
      delegatable_associations.each do |association|
        methods = Association::Methods.new(association, association_class)
        model.delegate methods.delegatable, delegation_options
      end
    end
  end
end
