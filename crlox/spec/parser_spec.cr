require "./spec_helper"

BINOP_PRECEDENCE = [
  ["==", "!="],
  [">", ">=", "<", "<="],
  ["-", "+"],
  ["/", "*"],
]

describe Parser do
  describe "#parse" do
    it "parses empty strings" do
      parse("").should eq nil
    end

    it "parses numbers" do
      parse("1").should eq Literal.new(1)
      parse("1.0").should eq Literal.new(1)
      parse("1.23").should eq Literal.new(1.23)
    end

    it "parses strings" do
      parse(%("")).should eq Literal.new("")
      parse(%("str")).should eq Literal.new("str")
      parse(%("str\nstr")).should eq Literal.new("str\nstr")
    end

    it "parses booleans" do
      parse("true").should eq Literal.new(true)
      parse("false").should eq Literal.new(false)
    end

    it "parses nil" do
      parse("nil").should eq Literal.new(nil)
    end

    it "parses unary expressions" do
      parse("-1").should eq Unary.new(token("-"), Literal.new(1))
      parse("-1.2").should eq Unary.new(token("-"), Literal.new(1.2))
      parse("!false").should eq Unary.new(token("!"), Literal.new(false))
    end

    it "parses double unary operators" do
      parse("--1").should eq Unary.new(token("-"), Unary.new(token("-"), Literal.new(1)))
      parse("!!false").should eq Unary.new(token("!"), Unary.new(token("!"), Literal.new(false)))
    end

    it "parses groupings" do
      parse("(1)").should eq Grouping.new(Literal.new(1))
      parse("((false))").should eq Grouping.new(Grouping.new(Literal.new(false)))
    end

    describe "binop" do
      it "parses left-associative" do
        ["==", "!=", ">", ">=", "<", "<=", "+", "-", "*", "/"].each do |operator|
          parse("1 #{operator} 2 #{operator} 3").should eq(
            Binary.new(
              Binary.new(
                Literal.new(1),
                token(operator),
                Literal.new(2)
              ),
              token(operator),
              Literal.new(3),
            )
          )
        end
      end

      it "respects equal binop precedence" do
        BINOP_PRECEDENCE.each do |operators|
          operators.each_permutation(2) do |(left, right)|
            parse("1 #{left} 2 #{right} 3").should eq(
              Binary.new(
                Binary.new(
                  Literal.new(1),
                  token(left),
                  Literal.new(2)
                ),
                token(right),
                Literal.new(3),
              )
            )
          end
        end
      end

      it "respects elevated binop precedence" do
        BINOP_PRECEDENCE.each_with_index do |operators, level|
          next if level == 0
          looser_operators = BINOP_PRECEDENCE[level - 1]
          operators.each do |tighter_operator|
            looser_operators.each do |looser_operator|
              parse("1 #{looser_operator} 2 #{tighter_operator} 3").should eq(
                Binary.new(
                  Literal.new(1),
                  token(looser_operator),
                  Binary.new(
                    Literal.new(2),
                    token(tighter_operator),
                    Literal.new(3)
                  ),
                )
              )
            end
          end
        end
      end

      it "respects tighter unary precedence" do
        parse("!false + -2").should eq(
          Binary.new(
            Unary.new(token("!"), Literal.new(false)),
            token("+"),
            Unary.new(token("-"), Literal.new(2))
          )
        )
      end
    end
  end
end
