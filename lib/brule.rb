# frozen_string_literal: true

require 'forwardable'

module Brule
  class Context
    extend Forwardable

    def_delegators :@content, :fetch, :fetch_values, :key?, :[]=, :merge!

    def self.wrap(context)
      context.is_a?(self) ? context : new(context)
    end

    def initialize(hash = {})
      @content = hash
    end

    def initialize_copy(orig)
      super
      @content = orig.instance_variable_get(:@content).dup
    end

    alias [] fetch
  end

  Rule = Struct.new(:config) do
    attr_accessor :context

    def trigger?
      true
    end

    def apply
      raise NotImplementedError
    end
  end

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
