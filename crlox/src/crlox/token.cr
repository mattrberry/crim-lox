module Crlox
  alias LiteralValue = String | Float64 | Bool | Nil
  record Token, type : TokenType, lexeme : String, literal : LiteralValue, line : Int32
end
