# frozen_string_literal: true

require 'test_helper'

class EngineTest < Minitest::Test
  Engine = Class.new(Brule::Engine) do
    def result_value
      context.key?(:result) ? context[:result] : 42
    end
  end

  def test_takes_a_collection_of_rules_to_instanciate
    assert Engine.new(rules: [])
  end

  def test_calling_the_engine_produces_a_result
    engine = Engine.new(rules: [])
    assert_kind_of Brule::Result, engine.call
  end

  def test_calling_the_engine_can_provide_a_context
    context_result = Object.new
    context = Brule::Context.wrap(result: context_result)
    engine = Engine.new(rules: [])
    result = engine.call(context)
    assert_same context_result, result.value
  end

  def test_engine_resuslt_embbeds_context
    engine = Engine.new(rules: [])
    result = engine.call(a: 42)
    assert_same 42, result.context[:a]
  end

  ValueToResultRule = Class.new(Brule::Rule) do
    def trigger?
      !config.key?(:skip)
    end

    def apply
      context[:result] = config[:value]
    end
  end

  def test_calling_the_engine_apply_rules_sequentially
    engine = Engine.new(
      rules: [
        ValueToResultRule.new(value: 10),
        ValueToResultRule.new(value: 20),
      ],
    )
    assert_equal 20, engine.call.value
  end

  def test_calling_the_engine_skip_rules_that_does_not_trigger
    engine = Engine.new(
      rules: [
        ValueToResultRule.new(value: 10),
        ValueToResultRule.new(value: 20, skip: true),
      ],
    )
    assert_equal 10, engine.call.value
  end
end
