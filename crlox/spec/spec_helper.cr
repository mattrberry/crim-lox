require "spec"
require "../src/crlox"
require "../src/crlox/*"

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

def parse(tokens : Array(Token)) : Expr?
  parser = Parser.new(tokens)
  parser.parse
end

# Relies on a reliable scanner implementation.
def parse(source : String) : Expr?
  parse(scan(source))
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

def interpret(source : String) : LiteralValue
  ast = parse(source)
  raise "Cannot parse #{source}" unless ast
  ast.accept(Interpreter.new)
end
