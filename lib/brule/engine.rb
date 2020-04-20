module Brule
  class Engine
    attr_reader :context

    def initialize(rules:)
      @rules = rules
    end

    def call(context = {})
      @history = {}
      @context = Context.wrap(context)
      snapshot!(tag: :initial)
      @rules.each { |rule| apply(rule) }
      result
    end

    def history(key:)
      return [] unless defined?(@history)

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
      snapshot!(tag: rule)
    end
  end
end
