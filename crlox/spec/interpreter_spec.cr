require "./spec_helper"

module Crlox
  describe Interpreter do
    describe "expressions" do
      Dir["#{Dir.current}/spec/examples/*.lox"].each do |file_path|
        in_path = Path[file_path]
        in_str = File.read(in_path)
        out_path = Path[in_path.dirname, in_path.basename.rpartition('.')[0] + ".out"]
        it "evaluates #{in_path.basename}" do
          out_str = File.exists?(out_path) ? File.read(out_path) : ""
          interpret(in_str).should eq out_str
        end
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
