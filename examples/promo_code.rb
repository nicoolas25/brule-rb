# To describe the loic behind coupon codes, Sunny shared a way of serializing
# logic into a Javascript objects. Here is a `Hash` version of something close.

coupon_config_hash = {
  conditions: [
    {
      operator: :gte,
      operands: [:order_amount, 42],
    },
    {
      operator: :lte,
      operands: [:past_usages_count, 99],
    },
  ],
  effects: [
    {
      type: :percentage,
      value: -10,
    }
  ],
}

# The idea is to have a set of `conditions` to match and if they are all a match
# then a set of `effects` to apply. This serialized representation of the logic
# can be stored in the database in a `json` field for instance.
#
# This is very flexible, each coupon can have an unique set of conditions and
# effects.

# ---
#
# On the other hand, if all the coupon end up being the same, maybe a couple of
# fields could represent it. It is small enough that we can even put the logic
# right now.

CouponConfig = Struct.new(:minimum_amount, :maximum_usage, :percent_discount, keyword_init: true) do
  def apply?(order_amount:, past_usages_count:)
    minimum_amount <= order_amount && past_usages_count < maximum_usage
  end

  def discount(order_amount:)
    order_amount * percent_discount / 100.0
  end
end

coupon_config = CouponConfig.new(
  minimum_amount: 42,
  maximum_usage: 100,
  percent_discount: -10,
)

coupon_config.apply?(order_amount: 32, past_usages_count: 99)   # => false
coupon_config.apply?(order_amount: 42, past_usages_count: 99)   # => true
coupon_config.apply?(order_amount: 42, past_usages_count: 100)  # => false

coupon_config.discount(order_amount: 100)  # => -10

# ---
#
# Going back to our `Hash` representation, we can achieve the same logic as in
# `CouponConfig` this way:

CouponConfig = Struct.new(:conditions, :effects, keyword_init: true) do
  CONDITION_OPERATIONS = {
    :gte => ->(operand1, operand2) { operand1 >= operand2 },
    :lte => ->(operand1, operand2) { operand1 <= operand2 },
  }

  def apply?(**context)
    conditions.all? do |condition|
      operator = condition.fetch(:operator)
      operands = condition.fetch(:operands).map { |op| context.fetch(op, op) }
      CONDITION_OPERATIONS.fetch(operator).call(*operands)
    end
  end

  DISCOUNT_EFFECTS = {
    percentage: ->(amount, value) { amount * (value / 100.0) }
  }

  def discount(order_amount:)
    effects.sum(0) do |effect|
      type, value = effect.fetch_values(:type, :value)
      DISCOUNT_EFFECTS.fetch(type).call(order_amount, value)
    end
  end
end

coupon_config = CouponConfig.new(**coupon_config_hash)

# It isn't _that_ bad but the flexibility definitely has a price here. Extra
# constants, loops that aren't used, obscure naming, and so on. The cognitive
# load of the engine is not that big.


