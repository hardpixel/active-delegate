module ActiveDelegate
  class Associations
    # Initialize assoctiations
    def initialize(model, options)
      @model   = model
      @options = default_options.merge(options)

      delegate_associations
    end

    private

      # Get default options
      def default_options
        { except: [], only: [], allow_nil: false, to: [] }
      end

      # Get association reflection
      def association_reflection
        assoc_name = @options.fetch(:to)
        reflection = @model.reflect_on_association(assoc_name)

        return reflection unless reflection.nil?
        raise "#{@model.name} don't have the association #{assoc_name}"
      end

      # Get model association class
      def association_class
        association_reflection.klass
      end

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
        associations = association_names.map(&:to_sym)
        associations = associations & @options[:only].to_a   if @options[:only].present?
        associations = associations - @options[:except].to_a if @options[:except].present?

        associations.map(&:to_sym)
      end

      # Check if association is collection
      def collection_association?(association)
        collections = association_reflections.select(&:collection?).map(&:name)
        association.in? collections
      end

      # Delegate associations
      def delegate_associations
        options = { to: @options[:to], allow_nil: @options[:allow_nil] }

        delegatable_associations.each do |association|
          @model.delegate "#{association}",  options
          @model.delegate "#{association}=", options

          @model.delegate "#{association}_attributes=", options rescue true
          @model.delegate "build_#{association}", options unless collection_association?(association)
        end
      end
  end
end
