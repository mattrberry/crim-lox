require "./interpreter"

module Crlox
  class LoxInstance
    @fields = Hash(String, LoxValue).new

    def initialize(@class : LoxClass)
    end

    def get(name : Token) : LoxValue
      if @fields.has_key?(name.lexeme)
        @fields[name.lexeme]
      elsif method = @class.find_method(name.lexeme)
        method.bind(self)
      else
        raise RuntimeError.new(name, "Undefined property '#{name.lexeme}'.")
      end
    end

    def set(name : Token, value : LoxValue) : Nil
      @fields[name.lexeme] = value
    end

    def to_s : String
      "#{@class.name} instance"
    end
  end
end
