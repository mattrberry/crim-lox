require "./token"
require "./exceptions"

module Crlox
  alias LoxValue = LiteralValue

  class Environment
    @values = Hash(String, LoxValue).new

    def get(name : Token) : LoxValue
      return @values[name.lexeme] if @values.has_key?(name.lexeme)
      raise RuntimeError.new(name, "Undefined variable '#{name.lexeme}'.")
    end

    def define(name : String, value : LoxValue) : Nil
      @values[name] = value
    end
  end
end
