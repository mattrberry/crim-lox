module Crlox
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
        "<native fn clock>"
      end
    end

    class LoxFunction < LoxCallable
      def initialize(@declaration : Stmt::Function, @closure : Environment, @is_initializer : Bool) : Nil
        super(@declaration.params.size)
      end

      def call(interpreter : Interpreter, arguments : Array(LoxValue)) : LoxValue
        environment = Environment.new(@closure)
        @declaration.params.zip(arguments) do |param, arg|
          environment.define(param.lexeme, arg)
        end
        interpreter.execute_block(@declaration.body, environment)
        @closure.get("this", 0) if @is_initializer
      rescue e : Return
        @is_initializer ? @closure.get("this", 0) : e.value
      end

      def bind(instance : LoxInstance) : LoxFunction
        env = Environment.new(@closure)
        env.define("this", instance)
        LoxFunction.new(@declaration, env, @is_initializer)
      end

      def to_s : String
        "<fn #{@declaration.name.lexeme}>"
      end
    end
  end
end
