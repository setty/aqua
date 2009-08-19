module Aqua::Config
  
  def self.included( klass ) 
    klass.class_eval do
      extend ClassMethods
      
      hide_attributes :_aqua_opts
    end  
  end 
  
  module ClassMethods
    def configure_aqua(opts={})
      @_aqua_opts = Mash( _aqua_config_defaults ).merge!(opts)
    end
    
    private
      def _aqua_config_defaults
        {
          :database => nil, # Default is the same as the server. Everything is saved to the same db
          :embed => false,  # options false, true, or :stub => [:attributes, :to_save, :in_the_other_object]
        }
      end
      
      def _aqua_opts
        @_aqua_opts
      end   
    public   
  end

end   