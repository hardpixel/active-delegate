module ActiveDelegate
  module Attribute
    class Accessor
      attr_reader :record, :options

      # Initialize attribute
      def initialize(record, options = {})
        @record  = record
        @options = options
      end

      # Get default value
      def default_value
        options[:default]
      end

      # Get association name
      def association_name
        options[:association].to_sym
      end

      # Get association attribute name
      def attribute_name
        options[:attribute].to_sym
      end

      # Get record attribute type
      def read_type
        options[:read_type]
      end

      # Get association attribute type
      def write_type
        options[:write_type]
      end

      # Check if should cast value
      def type_cast?
        read_type != write_type
      end

      # Get associated value
      def association_record
        record.send(association_name)
      end

      # Get association attribute value
      def attribute_value(*args)
        association_record.try(attribute_name, *args)
      end

      # Get record attribute type caster
      def read_type_caster
        lookup_type_caster(read_type)
      end

      # Get association attribute type caster
      def write_type_caster
        lookup_type_caster(write_type)
      end

      # Cast value for reading
      def cast_read_value(value)
        read_type_caster.cast(value)
      end

      # Cast value for writing
      def cast_write_value(value)
        write_type_caster.cast(value)
      end

      # Prepare association attribute value for writing
      def normalize_value(value)
        value = cast_read_value(value)
        cast_write_value(value)
      end

      # Read and cast value
      def read(*args)
        value = attribute_value(*args) || default_value
        type_cast? ? cast_read_value(value) : value
      end

      # Cast and write value
      def write(value)
        value = normalize_value(value) if type_cast?
        association_record.send(:"#{attribute_name}=", value)
      end

      private

      # Get type caster class
      def lookup_type_caster(type_caster)
        if type_caster.is_a?(Symbol)
          ActiveRecord::Type.lookup(type_caster)
        else
          type_caster
        end
      end
    end
  end
end
