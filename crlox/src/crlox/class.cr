require "./callable"
require "./instance"

module Crlox
  class LoxClass < LoxCallable
    getter name : String
    getter methods : Hash(String, LoxFunction)

    def initialize(@name : String, @methods : Hash(String, LoxFunction))
      super(0)
    end

    def call(interpreter : Interpreter, arguments : Array(LoxValue)) : LoxValue
      LoxInstance.new(self)
    end

    def find_method(name : String) : LoxFunction?
      methods[name]?
    end

    def to_s : String
      @name
    end
  end
end
