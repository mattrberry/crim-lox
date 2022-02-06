require "./token"
require "./token_type"
require "./scanner"
require "./parser"
require "./interpreter"

module Crlox
  class Lox
    @interpreter = Interpreter.new

    @@had_error = false
    @@had_runtime_error = false

    def run_file(file_path : String) : Nil
      run(File.read(file_path))
      exit 65 if @@had_error
      exit 70 if @@had_runtime_error
    end

    def run_prompt : Nil
      loop do
        print "> "
        line = gets
        break unless line
        run(line)
        @@had_error = false
        @@had_runtime_error = false
      end
    end

    def self.error(line : Int, message : String) : Nil
      report(line, "", message)
    end

    def self.error(token : Token, message : String) : Nil
      if token.type == TokenType::EOF
        report(token.line, " at end", message)
      else
        report(token.line, " at '#{token.lexeme}'", message)
      end
    end

    def self.runtime_error(error : RuntimeError) : Nil
      STDERR.puts("#{error.message}\n[line #{error.token.line}]")
      @@had_runtime_error = true
    end

    def self.report(line : Int, where : String, message : String) : Nil
      STDERR.puts("[line #{line}] Error#{where}: #{message}")
      @@had_error = true
    end

    def run(source : String) : Nil
      tokens = Scanner.new(source).scan_tokens
      program = Parser.new(tokens).parse
      return if @@had_error || program.nil?
      @interpreter.interpret(program)
    end
  end
end
