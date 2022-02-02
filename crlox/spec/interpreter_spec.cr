require "./spec_helper"

describe Interpreter do
  describe "expressions" do
    it "evaluates literals" do
      interpret("1").should eq 1
      interpret("false").should eq false
      interpret("true").should eq true
      interpret("nil").should eq nil
      interpret(%("string")).should eq "string"
      interpret("1.2").should eq 1.2
    end

    it "evaluates unarys" do
      interpret("-1").should eq -1
      interpret("--1").should eq 1
      interpret("!true").should eq false
      interpret("!!true").should eq true
      interpret("!nil").should eq true
      interpret("!0").should eq false
      interpret("!1").should eq false
      interpret("!-1").should eq false
    end

    it "evaluates groupings" do
      interpret("(1)").should eq 1
      interpret("((false))").should eq false
    end

    it "interprets binarys" do
      interpret("1 + 2").should eq 3
      interpret("1 - 2").should eq -1
      interpret("1 * 2").should eq 2
      interpret("1 / 2").should eq 0.5
      interpret(%("1" + "2")).should eq "12"
      interpret("1 == 1").should eq true
      interpret("1 == 2").should eq false
      interpret("1 == nil").should eq false
      interpret("1 == false").should eq false
      interpret("1 == true").should eq false
      interpret(%(1 == "1")).should eq false
      interpret("true == false").should eq false
      interpret("1 != 1").should eq false
      interpret("1 != 2").should eq true
      interpret("1 != nil").should eq true
      interpret("1 != true").should eq true
      interpret("1 != false").should eq true
      interpret(%(1 != "1")).should eq true
      interpret("false != true").should eq true
      interpret("1 < 2").should eq true
      interpret("1 <= 2").should eq true
      interpret("1 < 1").should eq false
      interpret("1 <= 1").should eq true
      interpret("1 > 2").should eq false
      interpret("1 >= 2").should eq false
      interpret("1 > 1").should eq false
      interpret("1 >= 1").should eq true
    end

    it "raises RuntimeErrors" do
      expect_raises(Interpreter::RuntimeError) { interpret("1 + false") }
      expect_raises(Interpreter::RuntimeError) { interpret("1 + nil") }
      expect_raises(Interpreter::RuntimeError) { interpret(%(1 + "1")) }
      expect_raises(Interpreter::RuntimeError) { interpret("-nil") }
      expect_raises(Interpreter::RuntimeError) { interpret("-false") }
    end
  end
end
