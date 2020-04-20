# frozen_string_literal: true

require 'test_helper'

class ContextTest < Minitest::Test
  Context = Brule::Context

  def test_wrap_a_hash
    assert_kind_of Context, Context.wrap(a: 1, b: 2)
  end

  def test_wrap_a_context
    context = Context.wrap(a: 1, b: 2)
    assert_same context, Context.wrap(context)
  end

  def test_read_key_with_brackets
    value = Object.new
    context = Context.wrap(key: value)
    assert_equal value, context[:key]
  end

  def test_read_missing_key_with_brackets
    empty_context = Context.wrap({})
    assert_raises(KeyError) { empty_context[:key] }
  end

  def test_read_multiple_keys_with_fetch_values
    context = Context.wrap(a: 1, b: 2)
    assert_equal [2, 1], context.fetch_values(:b, :a)
  end

  def test_read_missing_keys_with_fetch_values
    context = Context.wrap(a: 1, b: 2)
    assert_raises(KeyError) { context.fetch_values(:b, :c) }
  end

  def test_write_to_context
    context = Context.wrap(a: 1, b: 2)
    context[:a] = 3
    assert_equal 3, context[:a]
  end

  def test_presence_of_a_key
    context = Context.wrap(a: nil)
    assert context.key?(:a)
    refute context.key?(:b)
  end

  def test_updates_on_a_dup_does_not_update_original
    original_context = Context.wrap(a: nil)
    duped_context = original_context.dup
    duped_context[:a] = 42
    refute_equal original_context[:a], duped_context[:a]
  end
end
