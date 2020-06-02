# frozen_string_literal: true

module Brule
  class Engine
    attr_reader :context, :rules

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

    def to_hash
      { 'engine_class' => self.class.name, 'rules' => @rules.map(&:to_hash) }
    end

    def self.from_hash(hash)
      engine_class = Object.const_get(hash.fetch('engine_class'))
      rules = hash.fetch('rules').map do |rule_hash|
        rule_class = Object.const_get(rule_hash.fetch('rule_class'))
        rule_class.from_hash(rule_hash)
      end
      engine_class.new(rules: rules)
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
