module ActiveDelegate
  module Attribute
    class Accessor
      attr_reader :record, :options

      def initialize(record, options = {})
        @record  = record
        @options = options
      end

      def default_value
        options[:default]
      end

      def association_name
        options[:association].to_sym
      end

      def attribute_name
        options[:attribute].to_sym
      end

      def read_type
        options[:read_type]
      end

      def write_type
        options[:write_type]
      end

      def type_cast?
        read_type != write_type
      end

      def association_record
        record.send(association_name)
      end

      def attribute_value(*args)
        association_record.try(attribute_name, *args)
      end

      def read_type_caster
        lookup_type_caster(read_type)
      end

      def write_type_caster
        lookup_type_caster(write_type)
      end

      def cast_read_value(value)
        read_type_caster.cast(value)
      end

      def cast_write_value(value)
        write_type_caster.cast(value)
      end

      def normalize_value(value)
        value = cast_read_value(value)
        cast_write_value(value)
      end

      def read(*args)
        value = attribute_value(*args) || default_value
        type_cast? ? cast_read_value(value) : value
      end

      def write(value)
        value = normalize_value(value) if type_cast?
        association_record.send(:"#{attribute_name}=", value)
      end

      private

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
