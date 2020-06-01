# frozen_string_literal: true

require 'test_helper'

class RuleTest < Minitest::Test
  Rule = Brule::Rule

  def test_instanciation_with_a_configuration
    assert Rule.new(a: 1, b: 2)
  end

  def test_reading_configuration_from_the_rule
    config = Object.new
    assert_same config, Rule.new(config).config
  end

  def test_trigger_is_true_by_default
    assert Rule.new({}).trigger?
  end

  def test_apply_raises_by_default
    assert_raises(NotImplementedError) { Rule.new({}).apply }
  end

  def test_context_is_initially_nil
    rule = Rule.new({})
    assert_nil rule.context
  end

  def test_context_is_writable_and_readable
    rule = Rule.new({})
    context = {}
    rule.context = context
    assert_same context, rule.context
  end

  def test_rules_has_config_helpers
    config = { bar: 5 }
    context = {}
    rule_klass = Class.new(Rule) do
      config_reader :bar

      def apply
        context[:foo] = bar
      end
    end

    rule_klass.new(config).tap do |rule|
      rule.context = context
      rule.apply
    end

    assert 5, context.fetch_values(:foo)
  end

  def test_rules_has_context_helpers
    context = { foo: 5, bar: 2 }
    rule_klass = Class.new(Rule) do
      context_accessor :foo
      context_reader :bar
      context_writer :baz

      def apply
        self.foo = foo + bar
        self.baz = foo - bar
      end
    end

    rule_klass.new.tap do |rule|
      rule.context = context
      rule.apply
    end

    assert [7, 3], context.fetch_values(:foo, :baz)
  end
end
