require "./token"

module Crlox
  class ParseError < Exception
  end

  class RuntimeError < Exception
    getter token : Token

    def initialize(@token : Token, @message : String?) : Nil
    end
  end

  class Return < Exception
    getter value : LoxValue

    def initialize(@value : LoxValue) : Nil
    end
  end
end
