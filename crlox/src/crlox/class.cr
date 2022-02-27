require "./callable"
require "./instance"

module Crlox
  class LoxClass < LoxCallable
    getter name : String
    getter superclass : LoxClass?
    getter methods : Hash(String, LoxFunction)

    def initialize(@name : String, @superclass : LoxClass?, @methods : Hash(String, LoxFunction))
      super(find_method("init").try(&.arity) || 0)
    end

    def call(interpreter : Interpreter, arguments : Array(LoxValue)) : LoxValue
      instance = LoxInstance.new(self)
      if initializer = find_method("init")
        initializer.bind(instance).call(interpreter, arguments)
      end
      instance
    end

    def find_method(name : String) : LoxFunction?
      if method = methods[name]?
        method
      elsif superclass = @superclass
        superclass.find_method(name)
      end
    end

    def to_s : String
      @name
    end
  end
end
