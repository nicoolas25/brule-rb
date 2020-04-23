# frozen_string_literal: true

require 'test_helper'

class EitherTest < Minitest::Test
  Rule = Brule::Utils::Either

  MatchingRule = Class.new(Brule::Rule) do
    def trigger?
      return true if context.fetch(:match, false)
      return true if context.key?(:only) && context[:only] == config[:id]

      false
    end

    def apply
      context[:applied] = self
    end
  end

  def test_using_with_no_triggering_rules
    assert_raises(Brule::Utils::Either::NoMatchFound) do
      rule = Rule.new(
        rules: [
          MatchingRule.new,
          MatchingRule.new,
        ],
      )
      rule.context = Brule::Context.new
      rule.trigger?
    end
  end

  def test_using_with_multiple_triggering_rules
    assert_raises(Brule::Utils::Either::TooManyMatches) do
      rule = Rule.new(
        rules: [
          MatchingRule.new,
          MatchingRule.new,
        ],
      )
      rule.context = Brule::Context.new(match: true)
      rule.trigger?
    end
  end

  def test_using_with_a_single_matching_rule_it_triggers
    rule = Rule.new(
      rules: [
        MatchingRule.new(id: 1),
        MatchingRule.new(id: 2),
      ],
    )
    rule.context = Brule::Context.new(only: 2)
    assert rule.trigger?
  end

  def test_using_with_a_single_matching_rule_it_applies_the_right_rule
    rule = Rule.new(
      rules: [
        MatchingRule.new(id: 1),
        r2 = MatchingRule.new(id: 2),
      ],
    )
    rule.context = Brule::Context.new(only: 2)
    rule.apply
    assert_same r2, rule.context.fetch(:applied)
  end

  def test_using_with_a_single_matching_rule_it_tags_as_the_applied_rule
    rule = Rule.new(
      rules: [
        MatchingRule.new(id: 1),
        r2 = MatchingRule.new(id: 2),
      ],
    )
    rule.context = Brule::Context.new(only: 2)
    assert_same r2, rule.to_tag
  end
end
