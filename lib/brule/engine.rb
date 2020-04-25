module Brule
  class Engine
    attr_reader :context

    def initialize(rules:)
      @rules = rules
      @history = {}
    end

    def call(context = {})
      @history = {}
      @context = context
      snapshot!(tag: :initial)
      @rules.each { |rule| apply(rule) }
      result
    end

    def history(key:)
      @history.map { |tag, content| [tag, content.fetch(key, nil)] }
    end

    private

    def snapshot!(tag:)
      @history[tag] = @context.dup
    end

    def apply(rule)
      rule.context = @context
      return unless rule.trigger?

      rule.apply
      snapshot!(tag: rule.to_tag)
    end
  end
end
