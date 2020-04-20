module Brule
  class Engine
    attr_reader :context

    def initialize(rules:)
      @rules = rules
    end

    def call(context = {})
      Result.new.tap do |result|
        @context = Context.wrap(context)
        @rules.each do |rule|
          rule.context = @context
          rule.apply if rule.trigger?
        end
        result.context = @context
        result.value = result_value
      end
    end
  end
end
