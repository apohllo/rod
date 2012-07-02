require 'rod/constants'
require 'rod/native/collection_proxy'
require 'rod/model/resource'

module Rod
  module Model
    # Module representing a model entity.
    # Each storable class has to derive from +Model+.
    class Base
      include Resource

      # If +options+ is an integer it is the @rod_id of the object.
      def initialize(options=nil)
        @reference_updaters = []
        case options
        when Integer
          @rod_id = options
        when Hash
          @rod_id = 0
          initialize_fields
          options.each do |key,value|
            begin
              self.send("#{key}=",value)
            rescue NoMethodError
              raise RodException.new("There is no field or association with name #{key}!")
            end
          end
        when NilClass
          @rod_id = 0
          initialize_fields
        else
          raise InvalidArgument.new("initialize(options)",options)
        end
      end
    end
  end
end
