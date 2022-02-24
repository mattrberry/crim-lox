require "./interpreter"

module Crlox
  class LoxInstance
    @fields = Hash(String, LoxValue).new

    def initialize(@class : LoxClass)
    end

    def get(name : Token) : LoxValue
      unless @fields.has_key?(name.lexeme)
        raise RuntimeError.new(name, "Undefined property '#{name.lexeme}'.")
      end
      @fields[name.lexeme]
    end

    def set(name : Token, value : LoxValue) : Nil
      @fields[name.lexeme] = value
    end

    def to_s : String
      "#{@class.name} instance"
    end
  end
end
