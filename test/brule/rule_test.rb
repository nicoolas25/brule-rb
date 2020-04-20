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
    context = Brule::Context.new
    rule.context = context
    assert_same context, rule.context
  end
end
