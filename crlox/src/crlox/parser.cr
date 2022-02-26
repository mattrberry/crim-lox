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

    # declaration -> classDecl | funDecl | varDecl | statement
    # funDecl -> "fun" function
    private def declaration : Stmt?
      if match(TokenType::Class)
        class_declaration
      elsif match(TokenType::Fun)
        function("function")
      elsif match(TokenType::Var)
        var_declaration
      else
        statement
      end
    rescue error : ParseError
      synchronize
    end

    # classDecl -> "class" IDENTIFIER "{" function* "}"
    private def class_declaration : Stmt::Class
      name = consume(TokenType::Identifier, "Expect class name.")
      consume(TokenType::LeftBrace, "Expect '{' before class body.")
      methods = [] of Stmt::Function
      until check(TokenType::RightBrace) || at_end?
        methods << function("method")
      end
      consume(TokenType::RightBrace, "Expect '}' after class body.")
      Stmt::Class.new(name, methods)
    end

    # function -> IDENTIFIER "(" parameters? ")" block
    # parameters -> IDENTIFIER ( "," IDENTIFIER )*
    private def function(kind : String) : Stmt::Function
      name = consume(TokenType::Identifier, "Expect #{kind} name.")
      consume(TokenType::LeftParen, "Expect '(' after #{kind} name.")
      parameters = [] of Token
      unless check(TokenType::RightParen)
        loop do
          error(peek, "Can't have more than 255 parameters.") if parameters.size >= 255
          parameters << consume(TokenType::Identifier, "Expect paremeter name.")
          break unless match(TokenType::Comma)
        end
      end
      consume(TokenType::RightParen, "Expect ')' after parameters.")
      consume(TokenType::LeftBrace, "Expect '{' before #{kind} body.")
      body = block()
      Stmt::Function.new(name, parameters, body)
    end

    # varDecl -> "var" IDENTIFIER ( "=" expression )? ";"
    private def var_declaration : Stmt
      name = consume(TokenType::Identifier, "Expect variable name.")
      initializer = expression if match(TokenType::Equal)
      consume(TokenType::Semicolon, "Expect ';' after variable declaration.")
      Stmt::Var.new(name, initializer)
    end

    # statement -> exprStmt | forStmt | ifStmt | printStmt | whileStmt | block
    private def statement : Stmt
      if match(TokenType::If)
        if_statement
      elsif match(TokenType::For)
        for_statement
      elsif match(TokenType::Print)
        print_statement
      elsif match(TokenType::Return)
        return_statement
      elsif match(TokenType::While)
        while_statement
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

    # forStmt -> "for "(" ( varDecl | exprStmt )? ";" expression? ";" expression? ")" statement
    private def for_statement : Stmt
      consume(TokenType::LeftParen, "Expect '(' after 'for'.")
      if match(TokenType::Semicolon)
        # no initializer
      elsif match(TokenType::Var)
        initializer = var_declaration
      else
        initializer = expression_statement
      end
      condition = expression unless check(TokenType::Semicolon)
      consume(TokenType::Semicolon, "Expect ';' after loop condition.")
      increment = expression unless check(TokenType::RightParen)
      consume(TokenType::RightParen, "Expect ')' after for clauses.")
      body = statement
      # Desugaring
      body = Stmt::Block.new([body, Stmt::Expression.new(increment)]) if increment
      condition ||= Expr::Literal.new(true)
      body = Stmt::While.new(condition, body)
      body = Stmt::Block.new([initializer, body]) if initializer
      body
    end

    # ifStmt -> "if" "(" expression ")" statement ( "else" statement )?
    private def if_statement : Stmt
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

    # returnStmt -> "return" expression? ";"
    private def return_statement : Stmt
      keyword = previous()
      value = if check(TokenType::Semicolon)
                nil
              else
                expression()
              end
      consume(TokenType::Semicolon, "Expect ';' after return value.")
      Stmt::Return.new(keyword, value)
    end

    # whileStmt -> "while" "(" expression ")" statement
    private def while_statement : Stmt
      consume(TokenType::LeftParen, "Expect '(' after 'while'.")
      condition = expression
      consume(TokenType::RightParen, "Expect ')' after while condition.")
      body = statement
      Stmt::While.new(condition, body)
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
        if expr.is_a?(Expr::Variable)
          return Expr::Assign.new(expr.name, value)
        elsif expr.is_a?(Expr::Get)
          return Expr::Set.new(expr.object, expr.name, value)
        end
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

    # unary -> ( "!" | "-" ) unary | call
    private def unary : Expr
      if match(TokenType::Bang, TokenType::Minus)
        operator = previous
        right = unary
        Expr::Unary.new(operator, right)
      else
        call
      end
    end

    # call -> primary ( "(" arguments? ")" | "." IDENTIFIER )*
    private def call : Expr
      expr = primary
      loop do
        if match(TokenType::LeftParen)
          expr = finish_call(expr)
        elsif match(TokenType::Dot)
          name = consume(TokenType::Identifier, "Expect property name after '.'.")
          expr = Expr::Get.new(expr, name)
        else
          break
        end
      end
      expr
    end

    private def finish_call(callee : Expr) : Expr
      arguments = [] of Expr
      unless check(TokenType::RightParen)
        loop do
          error(peek, "Can't have more than 255 arguments.") if arguments.size >= 255
          arguments << expression
          break unless match(TokenType::Comma)
        end
      end
      paren = consume(TokenType::RightParen, "Expect ')' after arguments.")
      Expr::Call.new(callee, paren, arguments)
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
      elsif match(TokenType::This)
        Expr::This.new(previous)
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
