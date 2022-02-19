require "./spec_helper"

module Crlox
  describe Interpreter do
    describe "expressions" do
      it "evaluates literals" do
        interpret("print 1;").should eq "1"
        interpret("print false;").should eq "false"
        interpret("print true;").should eq "true"
        interpret("print nil;").should eq "nil"
        interpret(%(print "string";)).should eq "string"
        interpret("print 1.2;").should eq "1.2"
      end

      it "evaluates unarys" do
        interpret("print -1;").should eq "-1"
        interpret("print --1;").should eq "1"
        interpret("print !true;").should eq "false"
        interpret("print !!true;").should eq "true"
        interpret("print !nil;").should eq "true"
        interpret("print !0;").should eq "false"
        interpret("print !1;").should eq "false"
        interpret("print !-1;").should eq "false"
      end

      it "evaluates groupings" do
        interpret("print (1);").should eq "1"
        interpret("print ((false));").should eq "false"
      end

      it "interprets binarys" do
        interpret("print 1 + 2;").should eq "3"
        interpret("print 1 - 2;").should eq "-1"
        interpret("print 1 * 2;").should eq "2"
        interpret("print 1 / 2;").should eq "0.5"
        interpret(%(print "1" + "2";)).should eq "12"
        interpret("print 1 == 1;").should eq "true"
        interpret("print 1 == 2;").should eq "false"
        interpret("print 1 == nil;").should eq "false"
        interpret("print 1 == false;").should eq "false"
        interpret("print 1 == true;").should eq "false"
        interpret(%(print 1 == "1";)).should eq "false"
        interpret("print true == false;").should eq "false"
        interpret("print 1 != 1;").should eq "false"
        interpret("print 1 != 2;").should eq "true"
        interpret("print 1 != nil;").should eq "true"
        interpret("print 1 != true;").should eq "true"
        interpret("print 1 != false;").should eq "true"
        interpret(%(print 1 != "1";)).should eq "true"
        interpret("print false != true;").should eq "true"
        interpret("print 1 < 2;").should eq "true"
        interpret("print 1 <= 2;").should eq "true"
        interpret("print 1 < 1;").should eq "false"
        interpret("print 1 <= 1;").should eq "true"
        interpret("print 1 > 2;").should eq "false"
        interpret("print 1 >= 2;").should eq "false"
        interpret("print 1 > 1;").should eq "false"
        interpret("print 1 >= 1;").should eq "true"
      end

      # it "raises RuntimeErrors" do
      #   expect_raises(RuntimeError) { interpret("print 1 + false;") }
      #   expect_raises(RuntimeError) { interpret("print 1 + nil;") }
      #   expect_raises(RuntimeError) { interpret(%(print 1 + "1";)) }
      #   expect_raises(RuntimeError) { interpret("print -nil;") }
      #   expect_raises(RuntimeError) { interpret("print -false;") }
      # end
    end
  end
end
