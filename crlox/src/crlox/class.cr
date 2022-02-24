require "./callable"
require "./instance"

module Crlox
  class LoxClass < LoxCallable
    getter name : String

    def initialize(@name : String)
      super(0)
    end

    def call(interpreter : Interpreter, arguments : Array(LoxValue)) : LoxValue
      LoxInstance.new(self)
    end

    def to_s : String
      @name
    end
  end
end
