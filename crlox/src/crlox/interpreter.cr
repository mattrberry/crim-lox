require "./token"
require "./ast"
require "./exceptions"
require "./environment"

module Crlox
  alias LoxValue = LiteralValue | LoxCallable

  abstract class LoxCallable
    getter arity : Int32

    def initialize(@arity : Int32)
    end

    abstract def call(interpreter : Interpreter, arguments : Array(LoxValue)) : LoxValue

    class Clock < LoxCallable
      def initialize : Nil
        super(0)
      end

      def call(interpreter : Interpreter, arguments : Array(LoxValue)) : Float64
        Time.utc.to_unix_f
      end

      def to_s : String
        "<native fn clock"
      end
    end

    class LoxFunction < LoxCallable
      def initialize(@declaration : Stmt::Function) : Nil
        super(@declaration.params.size)
      end

      def call(interpreter : Interpreter, arguments : Array(LoxValue)) : LoxValue
        environment = Environment.new(interpreter.globals)
        @declaration.params.zip(arguments) do |param, arg|
          environment.define(param.lexeme, arg)
        end
        interpreter.execute_block(@declaration.body, environment)
      rescue e : Return
        e.value
      end

      def to_s : String
        "<fn #{@declaration.name.lexeme}>"
      end
    end
  end

  class Interpreter
    include Expr::Visitor(LoxValue)
    include Stmt::Visitor(Nil)

    getter globals : Environment

    def initialize : Nil
      @globals = Environment.new
      @environment = @globals
      @globals.define("clock", LoxCallable::Clock.new)
    end

    def interpret(program : Program) : Nil
      program.each { |statement| execute(statement) }
    rescue error : RuntimeError
      Lox.runtime_error(error)
    end

    def visit(stmt : Stmt::Expression) : Nil
      evaluate(stmt.expr)
    end

    def visit(stmt : Stmt::Function) : Nil
      function = LoxCallable::LoxFunction.new(stmt)
      @environment.define(stmt.name.lexeme, function)
    end

    def visit(stmt : Stmt::If) : Nil
      if truthy?(evaluate(stmt.condition))
        execute(stmt.then_branch)
      elsif else_branch = stmt.else_branch
        execute(else_branch)
      end
    end

    def visit(stmt : Stmt::Print) : Nil
      value = evaluate(stmt.expr)
      puts stringify(value)
    end

    def visit(stmt : Stmt::Return) : Nil
      raise Return.new(evaluate(stmt.value))
    end

    def visit(stmt : Stmt::While) : Nil
      while truthy?(evaluate(stmt.condition))
        execute(stmt.body)
      end
    end

    def visit(stmt : Stmt::Var) : Nil
      if initializer = stmt.initializer
        value = evaluate(initializer)
      end
      @environment.define(stmt.name.lexeme, value)
    end

    def visit(stmt : Stmt::Block) : Nil
      execute_block(stmt.statements, Environment.new(@environment))
    end

    def visit(expr : Expr::Binary) : LoxValue
      left = evaluate(expr.left)
      right = evaluate(expr.right)

      case expr.operator.type
      when TokenType::Greater
        check_number_operands(expr.operator, left, right)
        left.as(Float64) > right.as(Float64)
      when TokenType::GreaterEqual
        check_number_operands(expr.operator, left, right)
        left.as(Float64) >= right.as(Float64)
      when TokenType::Less
        check_number_operands(expr.operator, left, right)
        left.as(Float64) < right.as(Float64)
      when TokenType::LessEqual
        check_number_operands(expr.operator, left, right)
        left.as(Float64) <= right.as(Float64)
      when TokenType::BangEqual  then !equal?(left, right)
      when TokenType::EqualEqual then equal?(left, right)
      when TokenType::Minus
        check_number_operands(expr.operator, left, right)
        left.as(Float64) - right.as(Float64)
      when TokenType::Plus
        case {left, right}
        when {Float64, Float64} then left + right
        when {String, String}   then left + right
        else                         raise RuntimeError.new(expr.operator, "Operands must be two numbers or two strings.")
        end
      when TokenType::Slash
        check_number_operands(expr.operator, left, right)
        left.as(Float64) / right.as(Float64)
      when TokenType::Star
        check_number_operands(expr.operator, left, right)
        left.as(Float64) * right.as(Float64)
      end
    end

    def visit(expr : Expr::Call) : LoxValue
      callee = evaluate(expr.callee)
      unless callee.is_a?(LoxCallable)
        raise RuntimeError.new(expr.paren, "Can only call functions and classes.")
      end
      unless expr.arguments.size == callee.arity
        raise RuntimeError.new(expr.paren, "Expected #{callee.arity} arguments but got #{expr.arguments.size}.")
      end
      arguments = expr.arguments.map { |arg| evaluate(arg) }
      callee.call(self, arguments)
    end

    def visit(expr : Expr::Grouping) : LoxValue
      evaluate(expr.expression)
    end

    def visit(expr : Expr::Literal) : LoxValue
      expr.value
    end

    def visit(expr : Expr::Logical) : LoxValue
      left = evaluate(expr.left)
      if expr.operator.type == TokenType::Or
        return left if truthy?(left)
      else
        return left unless truthy?(left)
      end
      evaluate(expr.right)
    end

    def visit(expr : Expr::Unary) : LoxValue
      right = evaluate(expr.right)

      case expr.operator.type
      when TokenType::Minus
        check_number_operands(expr.operator, right)
        -(right.as(Float64))
      when TokenType::Bang then !truthy?(right)
      end
    end

    def visit(expr : Expr::Variable) : LoxValue
      @environment.get(expr.name)
    end

    def visit(expr : Expr::Assign) : LoxValue
      value = evaluate(expr.value)
      @environment.assign(expr.name, value)
      value
    end

    private def stringify(value : LoxValue) : String
      case value
      when Nil then "nil"
      when Float64
        text = value.to_s
        text.ends_with?(".0") ? text[..-3] : text
      else value.to_s
      end
    end

    private def evaluate(expr : Expr) : LoxValue
      expr.accept(self)
    end

    private def execute(stmt : Stmt) : Nil
      stmt.accept(self)
    end

    def execute_block(statements : Array(Stmt), environment : Environment) : Nil
      previous_env = @environment
      begin
        @environment = environment
        statements.each { |statement| execute(statement) }
      ensure
        @environment = previous_env
      end
    end

    private def truthy?(object : LoxValue) : Bool
      !!object # truthyness follows crystal semantics (false and nil are falsey)
    end

    private def equal?(left : LoxValue, right : LoxValue) : Bool
      left == right
    end

    private def check_number_operands(operator : Token, *operands : LoxValue) : Nil
      return if operands.all? &.is_a?(Float64)
      raise RuntimeError.new(operator, "Operand must be a number.")
    end
  end
end
