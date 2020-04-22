# frozen_string_literal: true

require 'test_helper'

class EngineTest < Minitest::Test
  Engine = Class.new(Brule::Engine) do
    def result
      context.key?(:result) ? context[:result] : 42
    end
  end

  def test_takes_a_collection_of_rules_to_instanciate
    assert Engine.new(rules: [])
  end

  def test_calling_the_engine_produces_a_result
    engine = Engine.new(rules: [])
    assert_equal 42, engine.call
  end

  def test_calling_the_engine_can_provide_a_context
    context_result = Object.new
    context = Brule::Context.wrap(result: context_result)
    engine = Engine.new(rules: [])
    result = engine.call(context)
    assert_same context_result, result
  end

  def test_engine_exposes_its_context
    engine = Engine.new(rules: [])
    value = Object.new
    engine.call(key: value)
    assert_kind_of Brule::Context, engine.context
    assert_same value, engine.context[:key]
  end

  ValueToResultRule = Class.new(Brule::Rule) do
    config_reader :value
    context_writer :result

    def trigger?
      !config.key?(:skip)
    end

    def apply
      self.result = value
    end
  end

  def test_calling_the_engine_apply_rules_sequentially
    engine = Engine.new(
      rules: [
        ValueToResultRule.new(value: 10),
        ValueToResultRule.new(value: 20),
      ],
    )
    assert_equal 20, engine.call
  end

  def test_calling_the_engine_skip_rules_that_does_not_trigger
    engine = Engine.new(
      rules: [
        ValueToResultRule.new(value: 10),
        ValueToResultRule.new(value: 20, skip: true),
      ],
    )
    assert_equal 10, engine.call
  end

  def test_engine_traces_history_of_context_entries
    engine = Engine.new(
      rules: [
        r1 = ValueToResultRule.new(value: 10),
        ValueToResultRule.new(value: 20, skip: true),
        r3 = ValueToResultRule.new(value: 30),
      ],
    )
    assert_equal 30, engine.call
    assert_equal [[:initial, nil], [r1, 10], [r3, 30]],
                 engine.history(key: :result)
  end
end
