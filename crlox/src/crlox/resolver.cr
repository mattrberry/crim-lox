require "./ast"
require "./interpreter"

module Crlox
  class Resolver
    include Expr::Visitor(Nil)
    include Stmt::Visitor(Nil)

    enum FunctionType
      None
      Function
      Method
    end

    @scopes = Array(Hash(String, Bool)).new
    @current_function_type = FunctionType::None

    def initialize(@interpreter : Interpreter)
    end

    def resolve(statements : Program) : Nil
      statements.each { |statement| resolve(statement) }
    end

    def visit(stmt : Stmt::Block) : Nil
      begin_scope
      resolve(stmt.statements)
      end_scope
    end

    def visit(stmt : Stmt::Var) : Nil
      declare(stmt.name)
      resolve(stmt.initializer.not_nil!) unless stmt.initializer.nil?
      define(stmt.name)
    end

    def visit(stmt : Stmt::Function) : Nil
      declare(stmt.name)
      define(stmt.name)
      resolve_function(stmt, FunctionType::Function)
    end

    def visit(stmt : Stmt::Expression) : Nil
      resolve(stmt.expr)
    end

    def visit(stmt : Stmt::If) : Nil
      resolve(stmt.condition)
      resolve(stmt.then_branch)
      resolve(stmt.else_branch.not_nil!) unless stmt.else_branch.nil?
    end

    def visit(stmt : Stmt::Print) : Nil
      resolve(stmt.expr)
    end

    def visit(stmt : Stmt::Return) : Nil
      if @current_function_type == FunctionType::None
        Lox.error(stmt.keyword, "Can't return from top-level code.")
      end
      resolve(stmt.value.not_nil!) unless stmt.value.nil?
    end

    def visit(stmt : Stmt::While) : Nil
      resolve(stmt.condition)
      resolve(stmt.body)
    end

    def visit(stmt : Stmt::Class) : Nil
      declare(stmt.name)
      define(stmt.name)
      stmt.methods.each do |method|
        resolve_function(method, FunctionType::Method)
      end
    end

    def visit(expr : Expr::Variable) : Nil
      if !@scopes.empty? && @scopes.last[expr.name.lexeme]? == false
        Lox.error(expr.name, "Can't read local variable in its own initializer.")
      end
      resolve_local(expr, expr.name)
    end

    def visit(expr : Expr::Assign) : Nil
      resolve(expr.value)
      resolve_local(expr, expr.name)
    end

    def visit(expr : Expr::Set) : Nil
      resolve(expr.value)
      resolve(expr.object)
    end

    def visit(expr : Expr::Binary) : Nil
      resolve(expr.left)
      resolve(expr.right)
    end

    def visit(expr : Expr::Call) : Nil
      resolve(expr.callee)
      expr.arguments.each { |arg| resolve(arg) }
    end

    def visit(expr : Expr::Get) : Nil
      resolve(expr.object)
    end

    def visit(expr : Expr::Grouping) : Nil
      resolve(expr.expression)
    end

    def visit(expr : Expr::Literal) : Nil
    end

    def visit(expr : Expr::Logical) : Nil
      resolve(expr.left)
      resolve(expr.right)
    end

    def visit(expr : Expr::Unary) : Nil
      resolve(expr.right)
    end

    private def begin_scope : Nil
      @scopes.push(Hash(String, Bool).new)
    end

    private def end_scope : Nil
      @scopes.pop
    end

    private def declare(name : Token) : Nil
      return if @scopes.empty?
      scope = @scopes.last
      if scope.has_key?(name.lexeme)
        Lox.error(name, "Already a variable with this name in this scope.")
      end
      scope[name.lexeme] = false
    end

    private def define(name : Token) : Nil
      return if @scopes.empty?
      @scopes.last[name.lexeme] = true
    end

    private def resolve(stmt : Stmt) : Nil
      stmt.accept(self)
    end

    private def resolve(expr : Expr) : Nil
      expr.accept(self)
    end

    private def resolve_local(expr : Expr, name : Token) : Nil
      (@scopes.size - 1).downto(0) do |idx|
        if @scopes[idx].has_key?(name.lexeme)
          @interpreter.resolve(expr, @scopes.size - 1 - idx)
          return
        end
      end
    end

    private def resolve_function(function : Stmt::Function, type : FunctionType) : Nil
      enclosing_function_type = @current_function_type
      @current_function_type = type

      begin_scope
      function.params.each do |param|
        declare(param)
        define(param)
      end
      resolve(function.body)
      end_scope

      @current_function_type = enclosing_function_type
    end
  end
end
