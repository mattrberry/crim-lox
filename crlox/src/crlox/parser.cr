require "./ast"
require "./token"
require "./token_type"

module Crlox
  class Parser
    @tokens : Array(Token)
    @current = 0

    def initialize(@tokens : Array(Token))
    end

    def parse : Program
      statements = Program.new
      until at_end?
        statement = declaration
        statements << statement unless statement.nil?
      end
      statements
    end

    # declaration -> varDecl | statement
    def declaration : Stmt?
      if match(TokenType::Var)
        var_declaration
      else
        statement
      end
    rescue error : ParseError
      synchronize
    end

    # varDecl -> "var" IDENTIFIER ( "=" expression )? ";"
    def var_declaration : Stmt
      name = consume(TokenType::Identifier, "Expect variable name.")
      initializer = expression if match(TokenType::Equal)
      consume(TokenType::Semicolon, "Expect ';' after variable declaration.")
      Stmt::Var.new(name, initializer)
    end

    # statement -> exprStmt | ifStmt | printStmt | block
    def statement : Stmt
      if match(TokenType::If)
        if_statement
      elsif match(TokenType::Print)
        print_statement
      elsif match(TokenType::LeftBrace)
        Stmt::Block.new(block)
      else
        expression_statement
      end
    end

    # exprStmt -> expression ";"
    private def expression_statement : Stmt
      expr = expression
      consume(TokenType::Semicolon, "Expect ';' after expression.")
      Stmt::Expression.new(expr)
    end

    # ifStmt -> "if" "(" expression ")" statement ( "else" statement )?
    def if_statement : Stmt
      consume(TokenType::LeftParen, "Expect '(' after 'if'.")
      condition = expression
      consume(TokenType::RightParen, "Expect ')' after if condition.")
      then_branch = statement()
      else_branch = statement if match(TokenType::Else)
      Stmt::If.new(condition, then_branch, else_branch)
    end

    # printStmt -> "print" expression ";"
    private def print_statement : Stmt
      value = expression
      consume(TokenType::Semicolon, "Expect ';' after value.")
      Stmt::Print.new(value)
    end

    # block -> "{" declaration* "}"
    private def block : Array(Stmt)
      statements = [] of Stmt
      until check(TokenType::RightBrace) || at_end?
        statement = declaration
        statements << statement unless statement.nil?
      end
      consume(TokenType::RightBrace, "Expect '}' after block.")
      statements
    end

    # expression -> assignment
    private def expression : Expr
      assignment
    end

    # assignment -> IDENTIFIER "=" assignment | logic_or
    private def assignment : Expr
      expr = or
      if match(TokenType::Equal)
        equals = previous
        value = assignment
        return Expr::Assign.new(expr.name, value) if expr.is_a?(Expr::Variable)
        error(equals, "Invalid assignment target.")
      end
      expr
    end

    # logic_or -> logic_and ( "or" logic_and )*
    private def or : Expr
      left_associative_logical_binop(->and, TokenType::Or)
    end

    # logic_and -> equality ( "and" equality )*
    private def and : Expr
      left_associative_logical_binop(->equality, TokenType::And)
    end

    # equality -> comparison ( ( "!=" | "==" ) comparison )*
    private def equality : Expr
      left_associative_binop(->comparison, TokenType::BangEqual, TokenType::EqualEqual)
    end

    # comparison -> term ( ( ">" | ">=" | "<" | "<=" ) term )*
    private def comparison : Expr
      left_associative_binop(->term, TokenType::Greater, TokenType::GreaterEqual, TokenType::Less, TokenType::LessEqual)
    end

    # term -> factor ( ( "-" | "+" ) factor )*
    private def term : Expr
      left_associative_binop(->factor, TokenType::Minus, TokenType::Plus)
    end

    # factor -> unary ( ( "/" | "*" ) unary )*
    private def factor : Expr
      left_associative_binop(->unary, TokenType::Slash, TokenType::Star)
    end

    # unary -> ( "!" | "-" ) unary | primary
    private def unary : Expr
      if match(TokenType::Bang, TokenType::Minus)
        operator = previous
        right = unary
        Expr::Unary.new(operator, right)
      else
        primary
      end
    end

    # primary -> "true" | "false" | "nil" | NUMBER | STRING | "(" expression ")" | IDENTIFIER
    private def primary : Expr
      if match(TokenType::False)
        Expr::Literal.new(false)
      elsif match(TokenType::True)
        Expr::Literal.new(true)
      elsif match(TokenType::Nil)
        Expr::Literal.new(nil)
      elsif match(TokenType::Number, TokenType::String)
        Expr::Literal.new(previous.literal)
      elsif match(TokenType::Identifier)
        Expr::Variable.new(previous)
      elsif match(TokenType::LeftParen)
        expr = expression
        consume(TokenType::RightParen, "Expect ')' after expression.")
        Expr::Grouping.new(expr)
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
        expr = Expr::Binary.new(expr, operator, right)
      end
      expr
    end

    # Matches a left-associative logical binop operation, where the *higher_prec_matcher* is the matcher
    # for the higher level of precedence, and *token_types* are the acceptable operators. This is distinct
    # from the left_associative_binop method because Expr::Logical is a separate type of expression, and I
    # couldn't find a way to make Crystal accept the class as an argument here.
    private def left_associative_logical_binop(higher_prec_matcher : -> Expr, *token_types : TokenType) : Expr
      expr = higher_prec_matcher.call
      while match(*token_types)
        operator = previous
        right = higher_prec_matcher.call
        expr = Expr::Logical.new(expr, operator, right)
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
      return false if at_end?
      peek.type == type
    end

    private def advance : Token
      @current += 1 unless at_end?
      previous
    end

    private def peek : Token
      @tokens[@current]
    end

    private def previous : Token
      @tokens[@current - 1]
    end

    private def at_end? : Bool
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
      until at_end?
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
end
