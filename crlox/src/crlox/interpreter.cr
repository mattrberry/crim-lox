require "./ast"
require "./token"

class Interpreter < ExprVisitor(LiteralValue)
  class RuntimeError < Exception
    getter token : Token

    def initialize(@token : Token, @message : String?)
    end
  end

  def interpret(expr : Expr) : Nil
    value = evaluate(expr)
    puts stringify(value)
  rescue error : RuntimeError
    Lox.runtime_error(error)
  end

  def visit(binary : Binary) : LiteralValue
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

  def visit(grouping : Grouping) : LiteralValue
    evaluate(grouping.expression)
  end

  def visit(literal : Literal) : LiteralValue
    literal.value
  end

  def visit(unary : Unary) : LiteralValue
    right = evaluate(unary.right)

    case unary.operator.type
    when TokenType::Minus
      check_number_operands(unary.operator, right)
      -(right.as(Float64))
    when TokenType::Bang then !truthy?(right)
    end
  end

  private def stringify(value : LiteralValue) : String
    case value
    when Nil then "nil"
    when Float64
      text = value.to_s
      text.ends_with?(".0") ? text[..-3] : text
    else value.to_s
    end
  end

  private def evaluate(expr : Expr) : LiteralValue
    expr.accept(self)
  end

  private def truthy?(object : LiteralValue) : Bool
    !!object # truthyness follows crystal semantics (false and nil are falsey)
  end

  private def equal?(left : LiteralValue, right : LiteralValue) : Bool
    left == right
  end

  private def check_number_operands(operator : Token, *operands : LiteralValue) : Nil
    return if operands.all? &.is_a?(Float64)
    raise RuntimeError.new(operator, "Operand must be a number.")
  end
end
