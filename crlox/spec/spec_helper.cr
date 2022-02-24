require "spec"
require "../src/crlox"
require "../src/crlox/*"

lib LibC
  fun dup(oldfd : LibC::Int) : LibC::Int
end

module Crlox
  AST_PRINTER = AstPrinter.new

  class Expr
    def inspect : String
      AST_PRINTER.print(self)
    end
  end

  def scan(source : String) : Array(Token)
    scanner = Scanner.new(source)
    scanner.scan_tokens
  end

  def parse(tokens : Array(Token)) : Program
    parser = Parser.new(tokens)
    parser.parse
  end

  # Relies on a reliable scanner implementation.
  def parse(source : String) : Program
    parse(scan(source))
  end

  def parse_expr(source : String, file = __FILE__, line = __LINE__) : Expr?
    statement = parse(source + ";")[0]?
    if statement.is_a?(Stmt::Expression)
      statement.expr
    else
      fail "[#{file}:#{line}] Did not parse espression from: #{source}"
    end
  end

  def token_type(lexeme : String) : TokenType
    case lexeme
    when "==" then TokenType::EqualEqual
    when "!=" then TokenType::BangEqual
    when ">"  then TokenType::Greater
    when ">=" then TokenType::GreaterEqual
    when "<"  then TokenType::Less
    when "<=" then TokenType::LessEqual
    when "+"  then TokenType::Plus
    when "-"  then TokenType::Minus
    when "*"  then TokenType::Star
    when "/"  then TokenType::Slash
    when "!"  then TokenType::Bang
    else           raise "Cannot match lexeme #{lexeme} to TokenType"
    end
  end

  def token(lexeme : String, line = 1) : Token
    Token.new(token_type(lexeme), lexeme, nil, line)
  end

  # Returns resulting stdout of program.
  def interpret(source : String) : String
    capture_stdout { Lox.new.run(source) }
  end

  # Capture stdout and return it as a string. Only reads until the final newline.
  def capture_stdout(&) : String
    stdout_fd = STDOUT.fd
    dup_fd = LibC.dup(stdout_fd)
    reader, writer = IO.pipe
    LibC.dup2(writer.fd, stdout_fd)
    yield
    writer.flush
    writer.close
    reader.read_timeout = 0
    result = String.build do |str|
      begin
        loop do
          str << reader.read_char
        end
      rescue
      end
    end
    reader.close
    LibC.dup2(dup_fd, stdout_fd)
    result
  end
end
