# Exceptions defined by the library.
module Rod
  # Base class for all Rod exceptions
  class RodException < Exception
    def initialize(message)
      @message = message
    end

    def to_s
      "Rod exception: #{@message}"
    end
  end

  # This exceptions is raised if there is a validation error.
  class ValidationException < RodException
    def initialize(message)
      @message = message
    end

    def to_s
      @message.join("\n")
    end
  end

  # Base exception class for database errors
  class DatabaseError < RodException
    def to_s
      "Database error: #{@message}"
    end
  end

  # This exception is raised if there is no database linked with the class.
  class MissingDatabase < DatabaseError
    def initialize(klass)
      @klass = klass
    end

    def to_s
      "Database not selected for class #{@klass}!\n" +
        "Provide the database class via call to Rod::Model.database_class."
    end
  end

  # This exception is raised if argument for some Rod API call
  # (such as field, has_one, has_many) is invalid.
  class InvalidArgument < RodException
    def initialize(value,type)
      @value = value
      @type = type
    end

    def to_s
      "The value '#@value' of the #@type is invalid!"
    end
  end
end