module Aqua
  class Stub
    attr_accessor :delegate, :delegate_class, :delegate_id, 
      :parent_object, :path_from_parent
    
    # Builds a new stub object which returns cached/stubbed methods until such a time as a non-cached method 
    # is requested.
    #
    # @param [Hash]
    # @option opts [Array] :methods A hash of method names and values
    # @option opts [String] :class The class of the object being stubbed
    # @option opts [String] :id The id of the object being stubbed
    #
    # @todo pass in information about parent, and path to the stub such that method missing replaces stub
    #         with actual object being stubbed and delegated to.
    # @api semi-public
    def initialize(opts)
      stub_methods( opts[:methods] || {} )
      
      self.delegate_class     = opts[:class]
      self.delegate_id        = opts[:id]
      self.parent_object      = opts[:parent]
      self.path_from_parent   = opts[:path] 
    end 
    
    def self.aqua_init( init, opts=Translator::Opts.new )
      new( init )
    end 
             
    protected 
      
      def stub_methods( stubbed_methods ) 
        stubbed_methods.each do |method_name, value|
          self.class.class_eval("
            def #{method_name}
              #{value.inspect}
            end  
          ")
        end
      end
      
      def missing_delegate_error
        raise ObjectNotFound, "Object of class '#{delegate_class}' and id '#{delegate_id}' not found"
      end  
               
      def method_missing( method, *args, &block )
        load_delegate if delegate.nil?
        if delegate
          delegate.send( method, *args, &block )
        else
          missing_delegate_error
        end    
      end
      
      def load_delegate 
        self.delegate = delegate_class.constantize.load( delegate_id )
      end   
  end

  class FileStub < Stub 
    attr_accessor :base_class, :base_id, :attachment_id 
      
    def initialize( opts )
      super( opts ) 
      self.base_class = opts[:base_object].class
      self.base_id =    opts[:base_id]
      self.attachment_id = opts[:id]
    end
    
    # This is what is actually called in the Aqua unpack process
    def self.aqua_init( init, opts )
      init['base_object'] = opts.base_object
      init['base_id'] = opts.base_id || opts.base_object.id # this is needed when an object is loaded, not reloaded
      super
    end
      
    protected  
      def missing_delegate_error 
        raise ObjectNotFound, "Attachment '#{attachment_id}' for '#{base_class}' with id='#{base_id}' not found."
      end  
      
      def load_delegate
        self.delegate = base_class::Storage.attachment( base_id, attachment_id )
      end   
  end            
  
end  