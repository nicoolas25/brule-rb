# frozen_string_literal: true

require 'test_helper'

class EitherTest < Minitest::Test
  Rule = Brule::Utils::Either

  MatchingRule = Class.new(Brule::Rule) do
    config_reader 'id'
    context_writer :applied

    def trigger?
      return true if context.fetch(:match, false)
      return true if context.key?(:only) && context[:only] == id

      false
    end

    def apply
      self.applied = self
    end
  end

  def test_using_with_no_triggering_rules
    assert_raises(Brule::Utils::Either::NoMatchFound) do
      rule = Rule.new(
        'rules' => [
          MatchingRule.new,
          MatchingRule.new,
        ],
      )
      rule.context = {}
      rule.trigger?
    end
  end

  def test_using_with_multiple_triggering_rules
    assert_raises(Brule::Utils::Either::TooManyMatches) do
      rule = Rule.new(
        'rules' => [
          MatchingRule.new,
          MatchingRule.new,
        ],
      )
      rule.context = { match: true }
      rule.trigger?
    end
  end

  def test_using_with_a_single_matching_rule_it_triggers
    rule = Rule.new(
      'rules' => [
        MatchingRule.new('id' => 1),
        MatchingRule.new('id' => 2),
      ],
    )
    rule.context = { only: 2 }
    assert rule.trigger?
  end

  def test_using_with_a_single_matching_rule_it_applies_the_right_rule
    rule = Rule.new(
      'rules' => [
        MatchingRule.new('id' => 1),
        r2 = MatchingRule.new('id' => 2),
      ],
    )
    rule.context = { only: 2 }
    rule.apply
    assert_same r2, rule.context.fetch(:applied)
  end

  def test_using_with_a_single_matching_rule_it_tags_as_the_applied_rule
    rule = Rule.new(
      'rules' => [
        MatchingRule.new('id' => 1),
        r2 = MatchingRule.new('id' => 2),
      ],
    )
    rule.context = { only: 2 }
    assert_same r2, rule.to_tag
  end

  def test_serialization
    rule1 = Rule.new(
      'rules' => [
        MatchingRule.new('id' => 1),
        MatchingRule.new('id' => 2),
      ],
    )
    rule2 = Rule.from_hash(rule1.to_hash)
    assert_equal rule1, rule2
  end
end
