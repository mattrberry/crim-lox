require "./token"

module Crlox
  alias Program = Array(Stmt)

  abstract class Stmt
    module Visitor(T)
      abstract def visit(stmt : Expression) : T
      abstract def visit(stmt : Function) : T
      abstract def visit(stmt : If) : T
      abstract def visit(stmt : Print) : T
      abstract def visit(stmt : Return) : T
      abstract def visit(stmt : Var) : T
      abstract def visit(stmt : While) : T
      abstract def visit(stmt : Block) : T
      abstract def visit(stmt : Class) : T
    end

    def accept(visitor : Visitor(T)) : T forall T
      visitor.visit(self)
    end

    class Expression < Stmt
      getter expr : Expr

      def_equals @expr

      def initialize(@expr : Expr)
      end
    end

    class Function < Stmt
      getter name : Token
      getter params : Array(Token)
      getter body : Array(Stmt)

      def_equals @name, @params, @body

      def initialize(@name : Token, @params : Array(Token), @body : Array(Stmt))
      end
    end

    class If < Stmt
      getter condition : Expr
      getter then_branch : Stmt
      getter else_branch : Stmt?

      def_equals @condition, @then_branch, @else_branch

      def initialize(@condition : Expr, @then_branch : Stmt, @else_branch : Stmt?)
      end
    end

    class Print < Stmt
      getter expr : Expr

      def_equals @expr

      def initialize(@expr : Expr)
      end
    end

    class Return < Stmt
      getter keyword : Token
      getter value : Expr

      def_equals @keyword, @value

      def initialize(@keyword : Token, @value : Expr)
      end
    end

    class Var < Stmt
      getter name : Token
      getter initializer : Expr?

      def_equals @name, @initializer

      def initialize(@name : Token, @initializer : Expr?)
      end
    end

    class While < Stmt
      getter condition : Expr
      getter body : Stmt

      def_equals @condition, @body

      def initialize(@condition : Expr, @body : Stmt)
      end
    end

    class Block < Stmt
      getter statements : Array(Stmt)

      def_equals @statements

      def initialize(@statements : Array(Stmt))
      end
    end

    class Class < Stmt
      getter name : Token
      getter methods : Array(Function)

      def_equals @name, @methods

      def initialize(@name : Token, @methods : Array(Stmt))
      end
    end
  end

  abstract class Expr
    module Visitor(T)
      abstract def visit(expr : Binary) : T
      abstract def visit(expr : Call) : T
      abstract def visit(expr : Get) : T
      abstract def visit(expr : Grouping) : T
      abstract def visit(expr : Literal) : T
      abstract def visit(expr : Logical) : T
      abstract def visit(expr : Unary) : T
      abstract def visit(expr : Variable) : T
      abstract def visit(expr : Assign) : T
      abstract def visit(expr : Set) : T
      abstract def visit(expr : This) : T
    end

    def accept(visitor : Visitor(T)) : T forall T
      visitor.visit(self)
    end

    class Binary < Expr
      getter left : Expr
      getter operator : Token
      getter right : Expr

      def_equals @left, @operator, @right

      def initialize(@left : Expr, @operator : Token, @right : Expr)
      end
    end

    class Call < Expr
      getter callee : Expr
      getter paren : Token
      getter arguments : Array(Expr)

      def_equals @callee, @paren, @arguments

      def initialize(@callee : Expr, @paren : Token, @arguments : Array(Expr))
      end
    end

    class Get < Expr
      getter object : Expr
      getter name : Token

      def_equals @object, @name

      def initialize(@object : Expr, @name : Token)
      end
    end

    class Grouping < Expr
      getter expression : Expr

      def_equals @expression

      def initialize(@expression : Expr)
      end
    end

    class Literal < Expr
      getter value : LiteralValue

      def_equals @value

      def initialize(@value : LiteralValue)
      end
    end

    class Logical < Expr
      getter left : Expr
      getter operator : Token
      getter right : Expr

      def_equals @left, @operator, @right

      def initialize(@left : Expr, @operator : Token, @right : Expr)
      end
    end

    class Unary < Expr
      getter operator : Token
      getter right : Expr

      def_equals @operator, @right

      def initialize(@operator : Token, @right : Expr)
      end
    end

    class Variable < Expr
      getter name : Token

      def_equals @name

      def initialize(@name : Token)
      end
    end

    class Assign < Expr
      getter name : Token
      getter value : Expr

      def_equals @name, @value

      def initialize(@name : Token, @value : Expr)
      end
    end

    class Set < Expr
      getter object : Expr
      getter name : Token
      getter value : Expr

      def_equals @object, @name, @value

      def initialize(@object : Expr, @name : Token, @value : Expr)
      end
    end

    class This < Expr
      getter keyword : Token

      def_equals @keyword

      def initialize(@keyword : Token)
      end
    end
  end
end
