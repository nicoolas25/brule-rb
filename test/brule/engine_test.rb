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
    context = { result: context_result }
    engine = Engine.new(rules: [])
    result = engine.call(context)
    assert_same context_result, result
  end

  def test_engine_exposes_its_context
    engine = Engine.new(rules: [])
    value = Object.new
    engine.call(key: value)
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

    def to_hash
      super do |config|
        # NOTE: stringify_keys would do
        { 'value' => config[:value] }.tap do |hash|
          hash['skip'] = config[:skip] if config.key?(:skip)
        end
      end
    end

    def self.from_hash(*)
      super do |config_hash|
        # NOTE: symbolize_keys would do
        { value: config_hash['value'] }.tap do |config|
          config[:skip] = config_hash['skip'] if config_hash.key?('skip')
        end
      end
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

  def test_engine_can_serialize_itself_into_a_hash
    engine = Engine.new(
      rules: [
        ValueToResultRule.new(value: 10),
        ValueToResultRule.new(value: 20, skip: true),
        ValueToResultRule.new(value: 30),
      ],
    )
    expected_hash = {
      'engine_class' => 'EngineTest::Engine',
      'rules' => [
        {
          'rule_class' => 'EngineTest::ValueToResultRule',
          'config' => { 'value' => 10 },
        },
        {
          'rule_class' => 'EngineTest::ValueToResultRule',
          'config' => { 'value' => 20, 'skip' => true },
        },
        {
          'rule_class' => 'EngineTest::ValueToResultRule',
          'config' => { 'value' => 30 },
        },
      ],
    }
    assert_equal expected_hash, engine.to_hash
  end

  def test_engine_can_deserialize_itself_from_a_hash
    engine = Engine.new(
      rules: [
        ValueToResultRule.new(value: 10),
        ValueToResultRule.new(value: 20, skip: true),
        ValueToResultRule.new(value: 30),
      ],
    )
    engine = Brule::Engine.from_hash(engine.to_hash)

    assert_kind_of Engine, engine
    assert_equal [ValueToResultRule] * 3, engine.rules.map(&:class)
    assert_equal [{ value: 10 }, { value: 20, skip: true }, { value: 30 }], engine.rules.map(&:config)
  end
end
