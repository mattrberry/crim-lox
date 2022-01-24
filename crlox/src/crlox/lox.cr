require "./scanner"
require "./token"
require "./token_type"

class Lox
  @@had_error = false

  def run_file(file_path : String) : Nil
    run(File.read(file_path))
    exit 65 if @@had_error
  end

  def run_prompt : Nil
    loop do
      print "> "
      line = gets
      break unless line
      run(line)
      @@had_error = false
    end
  end

  def self.error(line : Int, message : String) : Nil
    report(line, "", message)
  end

  def self.report(line : Int, where : String, message : String) : Nil
    STDERR.puts("[line #{line}] Error#{where}: #{message}")
    @@had_error = true
  end

  def run(source : String) : Nil
    scanner = Scanner.new(source)
    tokens = scanner.scan_tokens
    tokens.each { |token| puts token }
  end
end
