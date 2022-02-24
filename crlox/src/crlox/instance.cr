module Crlox
  class LoxInstance
    def initialize(@class : LoxClass)
    end

    def to_s : String
      "#{@class.name} instance"
    end
  end
end
