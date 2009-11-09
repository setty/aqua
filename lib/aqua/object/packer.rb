# Packing of objects needs to save an object as well as query it. Therefore this packer module gives a lot
# of class methods and mirrored instance methods that pack various types of objects. The instance methods
# aggregate all of the attachments and externals that need to be mapped back to the base object after they 
# are saved. The class methods return an array with the packaging in the first element and the attachment
# and externals in subsequent elements
module Aqua
  class Packer 
    attr_accessor :base
    
    def externals
      @externals ||= {}
    end
    
    def attachments
      @attachments ||= {}
    end    
    
    def initialize( base_object )
      self.base = base_object
    end 
    
    def pack
      rat = yield 
      self.externals += rat.externals
      self.attachments += rat.attachments
      rat.pack
    end  
    
    def self.pack_ivars( obj, path='' )
      rat = Rat.new
      vars = obj.respond_to?(:_storable_attributes) ? obj._storable_attributes : obj.instance_variables
      vars.each do |ivar_name|
        ivar = obj.instance_variable_get( ivar_name ) 
        if ivar 
          ivar_rat = pack_object( ivar )
          rat.hord( ivar_rat, ivar_name ) 
        end         
      end
      rat
    end 
    
    def pack_ivars( obj, path='' )
      pack { self.class.pack_ivars( obj ) }
    end
    
    def self.pack_object( obj, path='' )
      klass = obj.class
      if obj.respond_to?(:to_aqua) # probably requires special initialization not just ivar assignment
        obj.to_aqua( path )
      elsif obj.aquatic? && obj != self # if object is aquatic follow instructions for its class
        obj._embed_me == true ? obj._pack : pack_to_stub( obj, path ) 
      else # other object without initializations
        pack_vanilla( obj )
      end     
    end
    
    def pack_object( obj, path='' )
      pack { self.class.pack_object( obj ) }
    end
    
    
    # Packs the an object requiring no initialization.  
    #
    # @param Object to pack
    # @return [Mash] Indifferent hash that is the data/metadata deconstruction of an object.
    #
    # @api private  
    def self.pack_vanilla( obj, path='' )
      rat = Rat.new( { 'class' => obj.class.to_s } ) 
      ivar_rat = pack_ivars( obj )
      rat.hord( ivar_rat, 'ivars' ) unless ivar_rat.pack.empty?
      rat
    end 
    
    def pack_vanilla( obj, path='' )
      pack { self.class.pack_vanilla( obj ) }
    end
    
     
    # Packs the stub for an externally saved object.  
    #
    # @param Object to pack
    # @return [Mash] Indifferent hash that is the data/metadata deconstruction of an object.
    #
    # @api private    
    def self.pack_to_stub( obj, path='' )
      rat = Rat.new( {'class' => 'Aqua::Stub'})
      stub_rat = Rat.new({'class' => obj.class.to_s, 'id' => obj.id || '' }, {obj => path}, [])  
      # deal with cached methods
      if obj._embed_me && obj._embed_me.keys && stub_methods = obj._embed_me[:stub]
        stub_rat.pack['methods'] = {}
        if stub_methods.class == Symbol || stub_methods.class == String
          meth = stub_methods.to_s
          method_rat = pack_object( obj.send( meth ) ) 
          stub_rat.hord( method_rat, ['methods', "#{meth}"])
        else # is an array of values
          stub_methods.each do |meth|
            meth = meth.to_s
            method_rat = pack_object( obj.send( meth ) )
            stub_rat.hord( method_rat, ['methods', "#{meth}"])
          end  
        end    
      end
      rat.hord( stub_rat, 'init' )
    end
    
    def pack_to_stub( obj, path='' )
      pack { self.class.pack_to_stub( obj ) }
    end  
    
    # def pack_singletons
    #   # TODO: figure out 1.8 and 1.9 compatibility issues. 
    #   # Also learn the library usage, without any docs :(
    # end
                 
  end 
  
  class Rat 
    attr_accessor :pack, :externals, :attachments
    def initialize( pack={}, externals={}, attachments=[] )
      self.pack = pack
      self.externals = externals
      self.attachments = attachments
    end
    
    # merges the two rats
    def eat( other_rat )
      if self.pack.respond_to?(:keys) 
        self.pack.merge!( other_rat.pack )
      else
        self.pack << other_rat.pack  # this is a special case for array init rats
      end    
      self.externals.merge!( other_rat.externals )
      self.attachments += attachments
      self
    end
    
    # outputs and resets the accessor
    def barf( accessor )
      case accessor
      when :pack, 'pack'
        meal = self.pack
        self.pack = {}
      when :externals, 'externals'  
        meal = self.externals
        self.externals = {}  
      else
        meal = self.attachments
        self.attachments = []
      end    
      meal
    end
    
    def hord( other_rat, index)
      if [String, Symbol].include?( index.class ) 
        self.pack[index] = other_rat.barf(:pack) 
      else # for nested hording
        eval_string = index.inject("self.pack") do |result, element|
          element = "'#{element}'" if element.class == String
          result += "[#{element}]" 
        end 
        value = other_rat.barf(:pack)
        instance_eval "#{eval_string} = #{value.inspect}"
      end      
      self.eat( other_rat ) 
      self
    end
    
    def ==( other_rat ) 
      self.pack == other_rat.pack && self.externals == other_rat.externals && self.attachments == other_rat.attachments
    end    
          
  end   
end     