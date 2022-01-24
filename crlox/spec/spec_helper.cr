require "spec"
require "../src/crlox"
require "../src/crlox/*"

def scan(source : String) : Array(Token)
  scanner = Scanner.new(source)
  scanner.scan_tokens
end
