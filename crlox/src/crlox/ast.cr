require "./token"

module Crlox
  alias Program = Array(Stmt)

  abstract class Stmt
    module Visitor(T)
      abstract def visit(stmt : Expression) : T
      abstract def visit(stmt : If) : T
      abstract def visit(stmt : Print) : T
      abstract def visit(stmt : Var) : T
      abstract def visit(stmt : Block)
    end

    def accept(visitor : Visitor(T)) : T forall T
      visitor.visit(self)
    end

    class Expression < Stmt
      getter expr : Expr

      def_equals_and_hash @expr

      def initialize(@expr : Expr)
      end
    end

    class If < Stmt
      getter condition : Expr
      getter then_branch : Stmt
      getter else_branch : Stmt?

      def_equals_and_hash @condition, @then_branch, @else_branch

      def initialize(@condition : Expr, @then_branch : Stmt, @else_branch : Stmt?)
      end
    end

    class Print < Stmt
      getter expr : Expr

      def_equals_and_hash @expr

      def initialize(@expr : Expr)
      end
    end

    class Var < Stmt
      getter name : Token
      getter initializer : Expr?

      def_equals_and_hash @name, @initializer

      def initialize(@name : Token, @initializer : Expr?)
      end
    end

    class Block < Stmt
      getter statements : Array(Stmt)

      def_equals_and_hash @statements

      def initialize(@statements : Array(Stmt))
      end
    end
  end

  abstract class Expr
    module Visitor(T)
      abstract def visit(expr : Binary) : T
      abstract def visit(expr : Grouping) : T
      abstract def visit(expr : Literal) : T
      abstract def visit(expr : Logical) : T
      abstract def visit(expr : Unary) : T
      abstract def visit(expr : Variable) : T
      abstract def visit(expr : Assign) : T
    end

    def accept(visitor : Visitor(T)) : T forall T
      visitor.visit(self)
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

    class Logical < Expr
      getter left : Expr
      getter operator : Token
      getter right : Expr

      def_equals_and_hash @left, @operator, @right

      def initialize(@left : Expr, @operator : Token, @right : Expr)
      end
    end

    class Unary < Expr
      getter operator : Token
      getter right : Expr

      def_equals_and_hash @operator, @right

      def initialize(@operator : Token, @right : Expr)
      end
    end

    class Variable < Expr
      getter name : Token

      def_equals_and_hash @name

      def initialize(@name : Token)
      end
    end

    class Assign < Expr
      getter name : Token
      getter value : Expr

      def_equals_and_hash @name, @value

      def initialize(@name : Token, @value : Expr)
      end
    end
  end

  class AstPrinter
    include Expr::Visitor(String)

    def print(expr : Expr) : String
      expr.accept(self)
    end

    def visit(expr : Binary) : String
      parenthesize(expr.operator.lexeme, expr.left, expr.right)
    end

    def visit(expr : Grouping) : String
      parenthesize("group", expr.expression)
    end

    def visit(expr : Literal) : String
      if expr.value.nil?
        "nil"
      else
        expr.value.to_s
      end
    end

    def visit(expr : Unary) : String
      parenthesize(expr.operator.lexeme, expr.right)
    end

    def visit(expr : Variable) : String
      parenthesize("var", expr.name.lexeme)
    end

    def visit(expr : Assign) : String
      parenthesize("=", expr.name, expr.value)
    end

    private def parenthesize(name : String, *exprs : Expr) : String
      result = Array(String).new
      result << "(#{name}"
      exprs.each { |expr| result << " #{expr.accept(self)}" }
      result << ")"
      result.join
    end
  end
end
