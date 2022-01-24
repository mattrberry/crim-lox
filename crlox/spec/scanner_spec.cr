require "./spec_helper"

describe Scanner do
  describe "#scan_tokens" do
    it "scans empty files" do
      scan("").should eq([
        Token.new(TokenType::EOF, "", nil, 1),
      ])
    end

    it "scans single-character tokens" do
      scan("(){},.-+;/*").should eq([
        Token.new(TokenType::LeftParen, "(", nil, 1),
        Token.new(TokenType::RightParen, ")", nil, 1),
        Token.new(TokenType::LeftBrace, "{", nil, 1),
        Token.new(TokenType::RightBrace, "}", nil, 1),
        Token.new(TokenType::Comma, ",", nil, 1),
        Token.new(TokenType::Dot, ".", nil, 1),
        Token.new(TokenType::Minus, "-", nil, 1),
        Token.new(TokenType::Plus, "+", nil, 1),
        Token.new(TokenType::Semicolon, ";", nil, 1),
        Token.new(TokenType::Slash, "/", nil, 1),
        Token.new(TokenType::Star, "*", nil, 1),
        Token.new(TokenType::EOF, "", nil, 1),
      ])
    end

    it "scans comments" do
      scan("// comment here").should eq([
        Token.new(TokenType::EOF, "", nil, 1),
      ])
      scan("(//comment?").should eq([
        Token.new(TokenType::LeftParen, "(", nil, 1),
        Token.new(TokenType::EOF, "", nil, 1),
      ])
    end

    it "ignores whitespace" do
      scan(" \r\t + \t\r ").should eq([
        Token.new(TokenType::Plus, "+", nil, 1),
        Token.new(TokenType::EOF, "", nil, 1),
      ])
    end

    it "increments line on newlines" do
      scan("\n").should eq([
        Token.new(TokenType::EOF, "", nil, 2),
      ])
      scan("\n.\n").should eq([
        Token.new(TokenType::Dot, ".", nil, 2),
        Token.new(TokenType::EOF, "", nil, 3),
      ])
    end

    it "scans one or two character tokens" do
      scan("! != = == > >= < <=").should eq([
        Token.new(TokenType::Bang, "!", nil, 1),
        Token.new(TokenType::BangEqual, "!=", nil, 1),
        Token.new(TokenType::Equal, "=", nil, 1),
        Token.new(TokenType::EqualEqual, "==", nil, 1),
        Token.new(TokenType::Greater, ">", nil, 1),
        Token.new(TokenType::GreaterEqual, ">=", nil, 1),
        Token.new(TokenType::Less, "<", nil, 1),
        Token.new(TokenType::LessEqual, "<=", nil, 1),
        Token.new(TokenType::EOF, "", nil, 1),
      ])
    end

    it "scans strings" do
      scan(%("this is a string")).should eq([
        Token.new(TokenType::String, %("this is a string"), "this is a string", 1),
        Token.new(TokenType::EOF, "", nil, 1),
      ])
      scan(%("\n multiline \n string \n")).should eq([
        Token.new(TokenType::String, %("\n multiline \n string \n"), "\n multiline \n string \n", 4),
        Token.new(TokenType::EOF, "", nil, 4),
      ])
    end

    it "scans numbers" do
      scan("1 12 1.2 11.22").should eq([
        Token.new(TokenType::Number, "1", 1_f64, 1),
        Token.new(TokenType::Number, "12", 12_f64, 1),
        Token.new(TokenType::Number, "1.2", 1.2_f64, 1),
        Token.new(TokenType::Number, "11.22", 11.22_f64, 1),
        Token.new(TokenType::EOF, "", nil, 1),
      ])
    end

    it "scans identifiers" do
      scan("id foo bar Class And").should eq([
        Token.new(TokenType::Identifier, "id", nil, 1),
        Token.new(TokenType::Identifier, "foo", nil, 1),
        Token.new(TokenType::Identifier, "bar", nil, 1),
        Token.new(TokenType::Identifier, "Class", nil, 1),
        Token.new(TokenType::Identifier, "And", nil, 1),
        Token.new(TokenType::EOF, "", nil, 1),
      ])
    end

    it "scans keywords" do
      scan("and class else false fun for if nil or print return super this true var while").should eq([
        Token.new(TokenType::And, "and", nil, 1),
        Token.new(TokenType::Class, "class", nil, 1),
        Token.new(TokenType::Else, "else", nil, 1),
        Token.new(TokenType::False, "false", nil, 1),
        Token.new(TokenType::Fun, "fun", nil, 1),
        Token.new(TokenType::For, "for", nil, 1),
        Token.new(TokenType::If, "if", nil, 1),
        Token.new(TokenType::Nil, "nil", nil, 1),
        Token.new(TokenType::Or, "or", nil, 1),
        Token.new(TokenType::Print, "print", nil, 1),
        Token.new(TokenType::Return, "return", nil, 1),
        Token.new(TokenType::Super, "super", nil, 1),
        Token.new(TokenType::This, "this", nil, 1),
        Token.new(TokenType::True, "true", nil, 1),
        Token.new(TokenType::Var, "var", nil, 1),
        Token.new(TokenType::While, "while", nil, 1),
        Token.new(TokenType::EOF, "", nil, 1),
      ])
    end

    it "matches maximal characters on keywords" do
      scan("_and and_ anda aand").should eq([
        Token.new(TokenType::Identifier, "_and", nil, 1),
        Token.new(TokenType::Identifier, "and_", nil, 1),
        Token.new(TokenType::Identifier, "anda", nil, 1),
        Token.new(TokenType::Identifier, "aand", nil, 1),
        Token.new(TokenType::EOF, "", nil, 1),
      ])
    end
  end
end
