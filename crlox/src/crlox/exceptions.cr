require "./token"

module Crlox
  class ParseError < Exception
  end

  class RuntimeError < Exception
    getter token : Token

    def initialize(@token : Token, @message : String?)
    end
  end

  class Break < Exception
  end
end
