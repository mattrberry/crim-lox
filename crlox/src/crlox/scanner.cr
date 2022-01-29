class Scanner
  KEYWORDS = {
    "and"    => TokenType::And,
    "class"  => TokenType::Class,
    "else"   => TokenType::Else,
    "false"  => TokenType::False,
    "fun"    => TokenType::Fun,
    "for"    => TokenType::For,
    "if"     => TokenType::If,
    "nil"    => TokenType::Nil,
    "or"     => TokenType::Or,
    "print"  => TokenType::Print,
    "return" => TokenType::Return,
    "super"  => TokenType::Super,
    "this"   => TokenType::This,
    "true"   => TokenType::True,
    "var"    => TokenType::Var,
    "while"  => TokenType::While,
  }

  @source : String
  @tokens = Array(Token).new

  @start = 0
  @current = 0
  @line = 1

  def initialize(@source : String)
  end

  def scan_tokens : Array(Token)
    until is_at_end
      @start = @current
      scan_token
    end

    @tokens << Token.new(TokenType::EOF, "", nil, @line)
  end

  def is_at_end : Bool
    @current >= @source.size
  end

  def scan_token : Nil
    char = advance
    case char
    when '(' then add_token(TokenType::LeftParen)
    when ')' then add_token(TokenType::RightParen)
    when '{' then add_token(TokenType::LeftBrace)
    when '}' then add_token(TokenType::RightBrace)
    when ',' then add_token(TokenType::Comma)
    when '.' then add_token(TokenType::Dot)
    when '-' then add_token(TokenType::Minus)
    when '+' then add_token(TokenType::Plus)
    when ';' then add_token(TokenType::Semicolon)
    when '*' then add_token(TokenType::Star)
    when '!' then add_token(match('=') ? TokenType::BangEqual : TokenType::Bang)
    when '=' then add_token(match('=') ? TokenType::EqualEqual : TokenType::Equal)
    when '<' then add_token(match('=') ? TokenType::LessEqual : TokenType::Less)
    when '>' then add_token(match('=') ? TokenType::GreaterEqual : TokenType::Greater)
    when '/'
      if match('/')
        # a comment goes until the end of the line
        until peek == '\n' || is_at_end
          advance
        end
      else
        add_token(TokenType::Slash)
      end
    when ' ', '\r', '\t' # do nothing
    when '\n' then @line += 1
    when '"'  then string()
    else
      if is_digit(char)
        number()
      elsif is_alpha(char)
        identifier()
      else
        Lox.error(@line, "Unexpected character.")
      end
    end
  end

  def string : Nil
    until peek == '"' || is_at_end
      @line += 1 if peek == '\n'
      advance
    end
    if is_at_end
      Lox.error(@line, "Unterminated string.")
      return
    end
    advance # the closing "
    add_token(TokenType::String, @source[@start + 1...@current - 1])
  end

  def number : Nil
    while is_digit(peek)
      advance
    end
    if peek == '.' && is_digit(peek_next) # look for a fractional part
      advance                             # consume the "."
      while is_digit(peek)
        advance
      end
    end
    add_token(TokenType::Number, @source[@start...@current].to_f)
  end

  def identifier : Nil
    while is_alpha_numeric(peek)
      advance
    end
    add_token(KEYWORDS[@source[@start...@current]]? || TokenType::Identifier)
  end

  def advance : Char
    char = @source[@current]
    @current += 1
    char
  end

  def match(expected : Char) : Bool
    return false if is_at_end || @source[@current] != expected
    @current += 1
    true
  end

  def peek : Char
    return '\0' if is_at_end
    @source[@current]
  end

  def peek_next : Char
    return '\0' if @current + 1 >= @source.size
    @source[@current + 1]
  end

  def is_digit(char : Char) : Bool
    ('0'..'9').includes?(char)
  end

  def is_alpha(char : Char) : Bool
    ('a'..'z').includes?(char) || ('A'..'Z').includes?(char) || char == '_'
  end

  def is_alpha_numeric(char : Char) : Bool
    is_alpha(char) || is_digit(char)
  end

  def add_token(type : TokenType, literal : LiteralValue = nil)
    @tokens << Token.new(type, @source[@start...@current], literal, @line)
  end
end
