require "./token"
require "./exceptions"
require "./interpreter"

module Crlox
  class Environment
    getter values = Hash(String, LoxValue).new
    getter enclosing : Environment?

    def initialize(@enclosing : Environment? = nil)
    end

    def get(name : Token) : LoxValue
      return @values[name.lexeme] if @values.has_key?(name.lexeme)
      return @enclosing.not_nil!.get(name) unless @enclosing.nil?
      raise RuntimeError.new(name, "Undefined variable '#{name.lexeme}'.")
    end

    def get(name : String, distance : Int) : LoxValue
      ancestor(distance).values[name]?
    end

    def define(name : String, value : LoxValue) : Nil
      @values[name] = value
    end

    def assign(name : Token, value : LoxValue) : Nil
      if @values.has_key?(name.lexeme)
        @values[name.lexeme] = value
      elsif enclosing = @enclosing
        enclosing.assign(name, value)
      else
        raise RuntimeError.new(name, "Undefined variable '#{name.lexeme}'.")
      end
    end

    def assign(name : Token, value : LoxValue, distance : Int) : Nil
      ancestor(distance).values[name.lexeme] = value
    end

    private def ancestor(distance : Int) : Environment
      env = self
      distance.times { env = env.enclosing.not_nil! }
      env
    end
  end
end
