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

  def test_updates_on_a_dup_does_not_update_original
    original_context = Context.wrap(a: nil)
    duped_context = original_context.dup
    duped_context[:a] = 42
    refute_equal original_context[:a], duped_context[:a]
  end
end
