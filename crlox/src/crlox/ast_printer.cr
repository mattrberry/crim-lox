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

    def visit(stmt : Stmt::Class) : String
      String.build do |str|
        str << "(class "
        str << stmt.name
        if superclass = stmt.superclass
          str << " < "
          str << print(superclass)
        end
        str << " "
        str << stmt.methods.map(&.accept(self)).join('\n')
        str << ")"
      end
    end

    def visit(stmt : Stmt::Expression) : String
      print(stmt.expr) + ";"
    end

    def visit(stmt : Stmt::Function) : String
      "(fun #{stmt.name} (#{stmt.params.map &.lexeme}) #{print(body)})"
    end

    def visit(stmt : Stmt::If) : String
      String.build do |str|
        str << "(if ("
        str << print(stmt.condition)
        str << ") ("
        str << print(stmt.then_branch)
        str << ")"
        if else_branch = stmt.else_branch
          str << " ("
          str << print(else_branch)
          str << ")"
        end
        str << ")"
      end
    end

    def visit(stmt : Stmt::Print) : String
      "print #{print(stmt.expr)};"
    end

    def visit(stmt : Stmt::Return) : String
      "return #{print(stmt.value)};"
    end

    def visit(stmt : Stmt::Var) : String
      String.build do |str|
        str << "var "
        str << stmt.name.lexeme
        if initializer = stmt.initializer
          str << " = "
          str << print(initializer)
        end
      end
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

    def visit(expr : Expr::Call) : String
      "(#{print(expr.callee)} #{expr.arguments.map(&.accept(self)).join(" ")}})"
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

    def visit(expr : Expr::Get) : String
      "(#{visit(expr.object)}.#{expr.name.lexeme})"
    end

    def visit(expr : Expr::Set) : String
      "(#{visit(expr.object)}.#{expr.name.lexeme} = #{visit(expr.value)})"
    end

    def visit(expr : Expr::This) : String
      expr.keyword.lexeme
    end

    def visit(expr : Expr::Super) : String
      expr.keyword.lexeme
    end

    private def parenthesize(name : String, *exprs : Expr) : String
      String.build do |str|
        str << "(#{name}"
        exprs.each { |expr| str << " #{expr.accept(self)}" }
        str << ")"
      end
    end
  end
end
