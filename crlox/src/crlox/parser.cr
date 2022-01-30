require "./ast"
require "./token"
require "./token_type"

class Parser
  class ParseError < Exception
  end

  @tokens : Array(Token)
  @current = 0

  def initialize(@tokens : Array(Token))
  end

  def parse : Expr?
    expression
  rescue error : ParseError
  end

  # expression -> equality
  private def expression : Expr
    equality
  end

  # equality -> comparison ( ( "!=" | "==" ) comparison )*
  private def equality : Expr
    left_associative_binop(->comparison, TokenType::BangEqual, TokenType::EqualEqual)
  end

  # comparison ->  term ( ( ">" | ">=" | "<" | "<=" ) term )*
  private def comparison : Expr
    left_associative_binop(->term, TokenType::Greater, TokenType::GreaterEqual, TokenType::Less, TokenType::LessEqual)
  end

  # term -> factor ( ( "-" | "+" ) factor )*
  private def term : Expr
    left_associative_binop(->factor, TokenType::Minus, TokenType::Plus)
  end

  # factor -> unary ( ( "/" | "*" ) unary )* ;
  private def factor : Expr
    left_associative_binop(->unary, TokenType::Slash, TokenType::Star)
  end

  # unary -> ( "!" | "-" ) unary | primary
  private def unary : Expr
    if match(TokenType::Bang, TokenType::Minus)
      operator = previous
      right = unary
      Unary.new(operator, right)
    else
      primary
    end
  end

  # primary -> NUMBER | STRING | "true" | "false" | "nil" | "(" expression ")" ;
  private def primary : Expr
    if match(TokenType::False)
      Literal.new(false)
    elsif match(TokenType::True)
      Literal.new(true)
    elsif match(TokenType::Nil)
      Literal.new(nil)
    elsif match(TokenType::Number, TokenType::String)
      Literal.new(previous.literal)
    elsif match(TokenType::LeftParen)
      expr = expression
      consume(TokenType::RightParen, "Expect ')' after expression.")
      Grouping.new(expr)
    else
      raise error(peek, "Expect expression.")
    end
  end

  # Matches a left-associative binop operation, where the *higher_prec_matcher* is the matcher
  # for the higher level of precedence, and *token_types* are the acceptable operators.
  private def left_associative_binop(higher_prec_matcher : -> Expr, *token_types : TokenType) : Expr
    expr = higher_prec_matcher.call
    while match(*token_types)
      operator = previous
      right = higher_prec_matcher.call
      expr = Binary.new(expr, operator, right)
    end
    expr
  end

  private def match(*types : TokenType) : Bool
    types.each do |type|
      if check(type)
        advance
        return true
      end
    end
    false
  end

  private def check(type : TokenType) : Bool
    return false if is_at_end
    peek.type == type
  end

  private def advance : Token
    @current += 1 unless is_at_end
    previous
  end

  private def peek : Token
    @tokens[@current]
  end

  private def previous : Token
    @tokens[@current - 1]
  end

  private def is_at_end : Bool
    peek.type == TokenType::EOF
  end

  private def consume(type : TokenType, error_message : String) : Token
    return advance if check(type)
    raise error(peek, error_message)
  end

  private def error(token : Token, message : String) : ParseError
    Lox.error(token, message)
    ParseError.new
  end

  private def synchronize : Nil
    advance
    until is_at_end
      return if previous.type == TokenType::Semicolon
      case peek.type
      when TokenType::Class, TokenType::Fun, TokenType::Var,
           TokenType::For, TokenType::If, TokenType::While,
           TokenType::Print, TokenType::Return
        return
      end
      advance
    end
  end
end
