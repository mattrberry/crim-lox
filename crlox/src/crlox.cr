require "./crlox/lox"

module Crlox
  VERSION = "0.1.0"

  extend self

  def main
    lox = Lox.new
    case ARGV.size
    when 0 then lox.run_prompt
    when 1 then lox.run_file ARGV[0]
    else        abort "Usage: crlox [script]", 64
    end
  end
end

Crlox.main unless PROGRAM_NAME.includes?("crystal-run-spec")
