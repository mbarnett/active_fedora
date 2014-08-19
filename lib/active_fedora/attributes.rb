module ActiveFedora
  module Attributes
    extend ActiveSupport::Concern
    include ActiveModel::Dirty

    included do
      include Serializers
      include PrimaryKey

      after_save :clear_changed_attributes
      def clear_changed_attributes
        @previously_changed = changes
        @changed_attributes.clear
      end
    end

    def attributes=(properties)
      properties.each do |k, v|
        respond_to?(:"#{k}=") ? send(:"#{k}=", v) : raise(UnknownAttributeError, "#{self.class} does not have an attribute `#{k}'")
      end

    end


    def attributes
      self.class.defined_attributes.keys.each_with_object({"id" => id}) {|key, hash| hash[key] = self[key]}.merge(super)
    end

    # Calling inspect may trigger a bunch of datastream loads, but it's mainly for debugging, so no worries.
    def inspect
      values = ["pid: #{pid.inspect}"]
      values << self.class.defined_attributes.keys.map {|r| "#{r}: #{send(r).inspect}" }
      values << self.class.outgoing_reflections.values.map do |reflection|
        "#{reflection.foreign_key}: #{self[reflection.foreign_key].inspect}"
      end
      "#<#{self.class} #{values.flatten.join(', ')}>"
    end

    def [](key)
      if assoc = self.association(key.to_sym)
        # This is for id attributes stored in the rdf graph.
        assoc.reader
      elsif self.class.properties.key?(key)
        # The attribute is stored in the RDF graph for this object
        resource[key]
      else
        # The attribute is a delegate to a datastream
        array_reader(key)
      end
    end

    def []=(key, value)
      if assoc = self.association(key.to_sym)
        # This is for id attributes stored in the rdf graph.
        assoc.replace(value)
      elsif self.class.properties.key?(key)
        # The attribute is stored in the RDF graph for this object
        resource[key]=value
      else
        # The attribute is a delegate to a datastream
        array_setter(key, value)
      end
    end

    # @return [Boolean] true if there is an reader method and it returns a
    # value different from the new_value.
    def value_has_changed?(field, new_value)
      new_value != array_reader(field)
    end

    def mark_as_changed(field)
      self.send("#{field}_will_change!")
    end



    protected

    # override activemodel so it doesn't trigger a load of all the attributes.
    # the callback methods seem to trigger this, which means just initing an object (after_init)
    # causes a load of all the datastreams.
    def attribute_method?(attr_name) #:nodoc:
      respond_to_without_attributes?(:attributes) && self.class.defined_attributes.include?(attr_name)
    end

    private
    def array_reader(field, *args)
      raise UnknownAttributeError, "#{self.class} does not have an attribute `#{field}'" unless self.class.defined_attributes.key?(field)

      val = self.class.defined_attributes[field].reader(self, *args)
      self.class.multiple?(field) ? val : val.first
    end

    def array_setter(field, args)
      raise UnknownAttributeError, "#{self.class} does not have an attribute `#{field}'" unless self.class.defined_attributes.key?(field)
      if self.class.multiple?(field)
        if args.present? && !args.respond_to?(:each)
          raise ArgumentError, "You attempted to set the attribute `#{field}' on `#{self.class}' to a scalar value. However, this attribute is declared as being multivalued."
        end
      elsif args.respond_to?(:each) # singular
        raise ArgumentError, "You attempted to set the attribute `#{field}' on `#{self.class}' to an enumerable value. However, this attribute is declared as being singular."
      end
      self.class.defined_attributes[field].writer(self, args)
    end

    module ClassMethods
      def defined_attributes
        @defined_attributes ||= {}.with_indifferent_access
        return @defined_attributes unless superclass.respond_to?(:defined_attributes) and value = superclass.defined_attributes
        @defined_attributes = value.dup if @defined_attributes.empty?
        @defined_attributes
      end

      def defined_attributes= val
        @defined_attributes = val
      end

      def has_attributes(*fields)
        options = fields.pop
        datastream = options.delete(:datastream).to_s
        raise ArgumentError, "You must provide a datastream to has_attributes" if datastream.blank?
        define_attribute_methods fields
        fields.each do |f|
          create_attribute_reader(f, datastream, options)
          create_attribute_setter(f, datastream, options)
        end
      end

      # Reveal if the attribute has been declared unique
      # @param [Symbol] field the field to query
      # @return [Boolean]
      def unique?(field)
        !multiple?(field)
      end

      # Reveal if the attribute is multivalued
      # @param [Symbol] field the field to query
      # @return [Boolean]
      def multiple?(field)
        defined_attributes[field].multiple
      end

      def find_or_create_defined_attribute(field, dsid, args)
        self.defined_attributes[field] ||= DatastreamAttribute.new(field, dsid, datastream_class_for_name(dsid), args)
      end

      private

      def create_attribute_reader(field, dsid, args)
        find_or_create_defined_attribute(field, dsid, args)

        define_method field do |*opts|
          array_reader(field, *opts)
        end
      end

      def create_attribute_setter(field, dsid, args)
        find_or_create_defined_attribute(field, dsid, args)
        define_method "#{field}=".to_sym do |v|
          self[field]=v
        end
      end
    end
  end
end
