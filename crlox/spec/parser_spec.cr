require "./spec_helper"

module Crlox
  BINOP_PRECEDENCE = [
    ["==", "!="],
    [">", ">=", "<", "<="],
    ["-", "+"],
    ["/", "*"],
  ]

  describe Parser do
    describe "#parse" do
      it "parses empty strings" do
        parse("").should eq Program.new
      end

      it "parses numbers" do
        parse_expr("1").should eq Expr::Literal.new(1)
        parse_expr("1.0").should eq Expr::Literal.new(1)
        parse_expr("1.23").should eq Expr::Literal.new(1.23)
      end

      it "parses strings" do
        parse_expr(%("")).should eq Expr::Literal.new("")
        parse_expr(%("str")).should eq Expr::Literal.new("str")
        parse_expr(%("str\nstr")).should eq Expr::Literal.new("str\nstr")
      end

      it "parses booleans" do
        parse_expr("true").should eq Expr::Literal.new(true)
        parse_expr("false").should eq Expr::Literal.new(false)
      end

      it "parses nil" do
        parse_expr("nil").should eq Expr::Literal.new(nil)
      end

      it "parses unary expressions" do
        parse_expr("-1").should eq Expr::Unary.new(token("-"), Expr::Literal.new(1))
        parse_expr("-1.2").should eq Expr::Unary.new(token("-"), Expr::Literal.new(1.2))
        parse_expr("!false").should eq Expr::Unary.new(token("!"), Expr::Literal.new(false))
      end

      it "parses double unary operators" do
        parse_expr("--1").should eq Expr::Unary.new(token("-"), Expr::Unary.new(token("-"), Expr::Literal.new(1)))
        parse_expr("!!false").should eq Expr::Unary.new(token("!"), Expr::Unary.new(token("!"), Expr::Literal.new(false)))
      end

      it "parses groupings" do
        parse_expr("(1)").should eq Expr::Grouping.new(Expr::Literal.new(1))
        parse_expr("((false))").should eq Expr::Grouping.new(Expr::Grouping.new(Expr::Literal.new(false)))
      end

      describe "binop" do
        it "parses left-associative" do
          ["==", "!=", ">", ">=", "<", "<=", "+", "-", "*", "/"].each do |operator|
            parse_expr("1 #{operator} 2 #{operator} 3").should eq(
              Expr::Binary.new(
                Expr::Binary.new(
                  Expr::Literal.new(1),
                  token(operator),
                  Expr::Literal.new(2)
                ),
                token(operator),
                Expr::Literal.new(3),
              )
            )
          end
        end

        it "respects equal binop precedence" do
          BINOP_PRECEDENCE.each do |operators|
            operators.each_permutation(2) do |(left, right)|
              parse_expr("1 #{left} 2 #{right} 3").should eq(
                Expr::Binary.new(
                  Expr::Binary.new(
                    Expr::Literal.new(1),
                    token(left),
                    Expr::Literal.new(2)
                  ),
                  token(right),
                  Expr::Literal.new(3),
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
                parse_expr("1 #{looser_operator} 2 #{tighter_operator} 3").should eq(
                  Expr::Binary.new(
                    Expr::Literal.new(1),
                    token(looser_operator),
                    Expr::Binary.new(
                      Expr::Literal.new(2),
                      token(tighter_operator),
                      Expr::Literal.new(3)
                    ),
                  )
                )
              end
            end
          end
        end

        it "respects tighter unary precedence" do
          parse_expr("!false + -2").should eq(
            Expr::Binary.new(
              Expr::Unary.new(token("!"), Expr::Literal.new(false)),
              token("+"),
              Expr::Unary.new(token("-"), Expr::Literal.new(2))
            )
          )
        end
      end
    end
  end
end
