require "./token"
require "./ast"
require "./exceptions"
require "./environment"

module Crlox
  class Interpreter
    include Expr::Visitor(LoxValue)
    include Stmt::Visitor(Nil)

    @environment = Environment.new

    def interpret(program : Program) : Nil
      program.each { |statement| execute(statement) }
    rescue error : RuntimeError
      Lox.runtime_error(error)
    end

    def visit(expression : Stmt::Expression) : Nil
      evaluate(expression.expr)
    end

    def visit(print : Stmt::Print) : Nil
      value = evaluate(print.expr)
      puts stringify(value)
    end

    def visit(var : Stmt::Var) : Nil
      if initializer = var.initializer
        value = evaluate(initializer)
      end
      @environment.define(var.name.lexeme, value)
    end

    def visit(binary : Expr::Binary) : LoxValue
      left = evaluate(binary.left)
      right = evaluate(binary.right)

      case binary.operator.type
      when TokenType::Greater
        check_number_operands(binary.operator, left, right)
        left.as(Float64) > right.as(Float64)
      when TokenType::GreaterEqual
        check_number_operands(binary.operator, left, right)
        left.as(Float64) >= right.as(Float64)
      when TokenType::Less
        check_number_operands(binary.operator, left, right)
        left.as(Float64) < right.as(Float64)
      when TokenType::LessEqual
        check_number_operands(binary.operator, left, right)
        left.as(Float64) <= right.as(Float64)
      when TokenType::BangEqual  then !equal?(left, right)
      when TokenType::EqualEqual then equal?(left, right)
      when TokenType::Minus
        check_number_operands(binary.operator, left, right)
        left.as(Float64) - right.as(Float64)
      when TokenType::Plus
        case {left, right}
        when {Float64, Float64} then left + right
        when {String, String}   then left + right
        else                         raise RuntimeError.new(binary.operator, "Operands must be two numbers or two strings.")
        end
      when TokenType::Slash
        check_number_operands(binary.operator, left, right)
        left.as(Float64) / right.as(Float64)
      when TokenType::Star
        check_number_operands(binary.operator, left, right)
        left.as(Float64) * right.as(Float64)
      end
    end

    def visit(grouping : Expr::Grouping) : LoxValue
      evaluate(grouping.expression)
    end

    def visit(literal : Expr::Literal) : LoxValue
      literal.value
    end

    def visit(unary : Expr::Unary) : LoxValue
      right = evaluate(unary.right)

      case unary.operator.type
      when TokenType::Minus
        check_number_operands(unary.operator, right)
        -(right.as(Float64))
      when TokenType::Bang then !truthy?(right)
      end
    end

    def visit(variable : Expr::Variable) : LoxValue
      @environment.get(variable.name)
    end

    def visit(assign : Expr::Assign) : LoxValue
      value = evaluate(assign.value)
      @environment.assign(assign.name, value)
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
