alias LiteralValue = String | Float64 | Nil
record Token, type : TokenType, lexeme : String, literal : LiteralValue, line : Int32
