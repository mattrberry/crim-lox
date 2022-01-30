require "./token"

abstract class ExprVisitor(T)
  abstract def visit(binary : Binary) : T
  abstract def visit(grouping : Grouping) : T
  abstract def visit(literal : Literal) : T
  abstract def visit(unary : Unary) : T
end

abstract class Expr
  def accept(visitor : ExprVisitor(T)) : T forall T
    visitor.visit(self)
  end
end

class Binary < Expr
  getter left : Expr
  getter operator : Token
  getter right : Expr

  def_equals_and_hash @left, @operator, @right

  def initialize(@left : Expr, @operator : Token, @right : Expr)
  end
end

class Grouping < Expr
  getter expression : Expr

  def_equals_and_hash @expression

  def initialize(@expression : Expr)
  end
end

class Literal < Expr
  getter value : LiteralValue

  def_equals_and_hash @value

  def initialize(@value : LiteralValue)
  end
end

class Unary < Expr
  getter operator : Token
  getter right : Expr

  def_equals_and_hash @operator, @right

  def initialize(@operator : Token, @right : Expr)
  end
end

class AstPrinter < ExprVisitor(String)
  def print(expr : Expr) : String
    expr.accept(self)
  end

  def visit(binary : Binary) : String
    parenthesize(binary.operator.lexeme, binary.left, binary.right)
  end

  def visit(grouping : Grouping) : String
    parenthesize("group", grouping.expression)
  end

  def visit(literal : Literal) : String
    if literal.value.nil?
      "nil"
    else
      literal.value.to_s
    end
  end

  def visit(unary : Unary) : String
    parenthesize(unary.operator.lexeme, unary.right)
  end

  private def parenthesize(name : String, *exprs : Expr) : String
    result = Array(String).new
    result << "(#{name}"
    exprs.each { |expr| result << " #{expr.accept(self)}" }
    result << ")"
    result.join
  end
end
