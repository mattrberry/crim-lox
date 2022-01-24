alias Literal = String | Float64 | Nil
record Token, type : TokenType, lexeme : String, literal : Literal, line : Int32
