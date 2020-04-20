module Brule
  Rule = Struct.new(:config) do
    attr_accessor :context

    def trigger?
      true
    end

    def apply
      raise NotImplementedError
    end
  end
end
