require "./spec_helper"

describe AstPrinter do
  describe "#visit" do
    ast_printer = AstPrinter.new

    plus = token("+")
    bang = token("!")
    lit1 = Literal.new(1.3)
    lit2 = Literal.new(false)
    grouping = Grouping.new(lit2)
    unary = Unary.new(bang, lit2)
    binary = Binary.new(lit1, plus, unary)

    it "prints literal" do
      ast_printer.print(lit1).should eq "1.3"
      ast_printer.print(lit2).should eq "false"
    end

    it "prints grouping" do
      ast_printer.print(grouping).should eq "(group false)"
    end

    it "prints unary" do
      ast_printer.print(unary).should eq "(! false)"
    end

    it "prints binary" do
      ast_printer.print(binary).should eq "(+ 1.3 (! false))"
    end
  end
end
