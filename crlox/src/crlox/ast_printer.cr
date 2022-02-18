require "./ast"

module Crlox
  class AstPrinter
    include Expr::Visitor(String)
    include Stmt::Visitor(String)

    def print(expr : Expr) : String
      expr.accept(self)
    end

    def print(stmt : Stmt) : String
      stmt.accept(self)
    end

    def print(program : Program) : String
      program.map(&.accept(self)).join('\n')
    end

    def visit(stmt : Stmt::Expression) : String
      print(stmt.expr) + ";"
    end

    def visit(stmt : Stmt::If) : String
      result = [] of String
      result << "if ("
      result << print(stmt.condition)
      result << ") "
      result << print(stmt.then_branch)
      if else_branch = stmt.else_branch
        result << " else "
        result << print(else_branch)
      end
      result.join
    end

    def visit(stmt : Stmt::Print) : String
      "print " + print(stmt.expr) + ";"
    end

    def visit(stmt : Stmt::Var) : String
      result = [] of String
      result << "var "
      result << stmt.name.lexeme
      if initializer = stmt.initializer
        result << " = "
        result << print(initializer)
      end
      result.join
    end

    def visit(stmt : Stmt::While) : String
      "while (" + print(stmt.condition) + ") " + print(stmt.body)
    end

    def visit(stmt : Stmt::Block) : String
      "{ " + stmt.statements.map(&.accept(self)).join(" ") + " }"
    end

    def visit(expr : Expr::Binary) : String
      parenthesize(expr.operator.lexeme, expr.left, expr.right)
    end

    def visit(expr : Expr::Grouping) : String
      parenthesize("group", expr.expression)
    end

    def visit(expr : Expr::Literal) : String
      if expr.value.nil?
        "nil"
      else
        expr.value.to_s
      end
    end

    def visit(expr : Expr::Logical) : String
      parenthesize(expr.operator.lexeme, expr.left, expr.right)
    end

    def visit(expr : Expr::Unary) : String
      parenthesize(expr.operator.lexeme, expr.right)
    end

    def visit(expr : Expr::Variable) : String
      expr.name.lexeme
    end

    def visit(expr : Expr::Assign) : String
      "(#{expr.name.lexeme} = #{print(expr.value)})"
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