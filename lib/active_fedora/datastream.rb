module ActiveFedora

  #This class represents a Fedora datastream
  class Datastream < Rubydora::Datastream
    
    attr_writer :digital_object
    attr_accessor :dirty, :last_modified, :fields
    before_create :add_mime_type, :add_ds_location
  
    def initialize(digital_object, dsid, options={})
      ## When you use the versions feature of rubydora (0.5.x), you need to have a 3 argument constructor
      self.fields={}
      self.dirty = false
      super
    end
    
    def size
      self.profile['dsSize']
    end

    def add_mime_type
      self.mimeType = 'text/xml' unless self.mimeType
    end

    def add_ds_location
      if self.controlGroup == 'E'
      end
    end

    def inspect
      "#<#{self.class}:#{self.hash} @pid=\"#{pid}\" @dsid=\"#{dsid}\" @controlGroup=\"#{controlGroup}\" @dirty=\"#{dirty}\" @mimeType=\"#{mimeType}\" >"
    end

    #compatibility method for rails' url generators. This method will 
    #urlescape escape dots, which are apparently
    #invalid characters in a dsid.
    def to_param
      dsid.gsub(/\./, '%2e')
    end
    
    # Test whether this datastream been modified since it was last saved
    def dirty?
      dirty || changed?
    end

    def new_object?
      new?
    end

    def save
      #raise "No content #{dsid}" if @content.nil?
      return if @content.nil?
      run_callbacks :save do
        return create if new?
        repository.modify_datastream to_api_params.merge({ :pid => pid, :dsid => dsid })
        reset_profile_attributes
        #Datastream.new(digital_object, dsid)
        self
      end
    end

    def create
      run_callbacks :create do
        repository.add_datastream to_api_params.merge({ :pid => pid, :dsid => dsid })
        reset_profile_attributes
        self
      end
    end


    # serializes any changed data into the content field
    def serialize!
    end
    # Populate a Datastream object based on the "datastream" node from a FOXML file
    # @param [ActiveFedora::Datastream] tmpl the Datastream object that you are building
    # @param [Nokogiri::XML::Node] node the "foxml:datastream" node from a FOXML file
    def self.from_xml(tmpl, node)
      tmpl.instance_variable_set(:@dirty, false)
      tmpl.controlGroup= node['CONTROL_GROUP']
      tmpl
    end
    
    def check_concurrency # :nodoc:
      return true
    end
    
  end
  
  class DatastreamConcurrencyException < Exception # :nodoc:
  end
end
