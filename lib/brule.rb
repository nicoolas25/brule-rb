# frozen_string_literal: true

require 'forwardable'

module Brule
  module RuleHelpers
    def context_reader(*symbols)
      symbols.each do |symbol|
        define_method(symbol) { context.fetch(symbol) }
      end
    end

    def context_writer(*symbols)
      symbols.each do |symbol|
        define_method("#{symbol}=") { |value| context[symbol] = value }
      end
    end

    def context_accessor(*symbols)
      context_reader(*symbols)
      context_writer(*symbols)
    end

    def config_reader(*symbols)
      symbols.each do |symbol|
        define_method(symbol) { config.fetch(symbol) }
      end
    end
  end

  Rule = Struct.new(:config) do
    extend RuleHelpers

    attr_accessor :context

    def trigger?
      true
    end

    def apply
      raise NotImplementedError
    end
  end

  class Context
    extend Forwardable

    def_delegators :@content, :[], :fetch, :fetch_values, :key?, :[]=, :merge!

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
  end

  class Engine
    attr_reader :context

    def initialize(rules:)
      @rules = rules
      @history = {}
    end

    def call(context = {})
      @history = {}
      @context = Context.wrap(context)
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
      snapshot!(tag: rule)
    end
  end
end
