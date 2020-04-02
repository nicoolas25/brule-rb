# This example is from the perpective of a car rental company. It revolves
# around the pricing of a car for a given `Rental`.
#
# A `Rental` represents a _car_ being shared for a given _period_ of time.

Rental = Struct.new(:car, :period, keyword_init: true)

# ---
#
# At the beginning, `2020-04-01`, logic is simple. There is one way to
# compute the price of a `Rental`. It is the _price per day_ times the
# _number of days_.

class Rental
  def price
    duration * car.price_per_day
  end

  def duration
    1 + (period.end_on - period.start_on).to_i
  end
end

# To show the whole code, here are the `Car` and `Period` class. One could easily
# argue and convice me to put `#duration` in period rather than in `Rental`.

require "date"

Car = Struct.new(:price_per_day, keyword_init: true)

Period = Struct.new(:start_at, :end_at, keyword_init: true) do
  def start_on
    start_at.to_date
  end

  def end_on
    end_at.to_date
  end
end

# ---
#
# Because the `Car#price_per_day` can change outside of the lifecycle of a
# `Rental`, we'll denormalize it. Without that, the `Rental#price` could change
# if the `Car#price_per_day` is updated.

car = Car.new(price_per_day: 30)
rental = Rental.new(
  car: car,
  period: Period.new(
    start_at: Time.utc(2020, 4, 1),
    end_at: Time.utc(2020, 4, 3),
  ),
)

rental.price # => 90

# That is the situation we want to avoid:
car.price_per_day = 10
rental.price # => 30

# Let's reopen the `Rental` class and add stuff to avoid it...

class Rental
  attr_reader :car_price_per_day

  def initialize(*)
    super
    @car_price_per_day = car.price_per_day
  end

  def price
    duration * car_price_per_day
  end
end

# ---
#
# A `Rental` can be updated. It means that its start_on and end_on dates can be
# updated. The desired side-effect of that is to change the `Rental#price`. Here
# I decided to instanciate another `Rental`, keeping the denormalized price of
# the car: `@car_price_per_day`.

class Rental
  def adjust(new_period)
    dup.tap do |new_rental|
      new_rental.period = new_period
    end
  end
end

# ---
#
# Starting from `2020-06-01` we'll introduce a new way to do the pricing. The
# new feature will be called _"discounts"_. If the longer is the rental the more
# its price will decrease. For this iteration, the discount, in percentage, will
# follow this formula:
#
# `discount = min(40, max(0, 2 * duration - 4))`
#
# <img alt="https://cl.ly/20ef2ddde07a" src="https://cl.ly/20ef2ddde07a/discount.png" width="100%" />

class Rental
  def price
    duration * car_price_per_day * (1 - discount)
  end

  def discount
    (2 * duration - 4).clamp(0, 40) / 100.0
  end
end

# That should work. But what about rentals from before `2020-06-01`? And what
# does _"a rental from before `2020-06-01`"_ means? To know which pricing to
# use, we need to answer that first.

# We consider the time the car was selected by the driver as the reference time
# to decide which pricing must apply. We can change a bit the `Rental` to
# include that information.

Rental = Struct.new(:car, :period, :selected_at, keyword_init: true)

# From there, we can tweak the discount method to add a conditional:

class Rental
  DISCOUNT_APPLY_AFTER = Time.utc(2020, 6, 1)

  def discount
    if selected_at >= DISCOUNT_APPLY_AFTER
      (2 * duration - 4).clamp(0, 40) / 100.0
    else
      0.0
    end
  end
end

# If we take a rental that spans on 3 days, we can see the discount is being
# applied only when the `selected_at` is after `DISCOUNT_APPLY_AFTER`.

price_for_3_days = ->(selected_at) {
  Rental.new(
    car: Car.new(price_per_day: 30),
    period: Period.new(
      start_at: Time.utc(2020, 10, 1, 8),  # 2020-10-01 08:00
      end_at: Time.utc(2020, 10, 3, 12),   # 2020-10-03 12:00
    ),
    selected_at: selected_at,
  ).price.round(2)
}

price_for_3_days.call(Time.utc(2020, 5, 15))  # => 90.0
price_for_3_days.call(Time.utc(2020, 6, 15))  # => 88.2 (2% discount)

# ---
#
# This starts to smell bad for the long term already. If requirements
# continue to pile up like this, the pricing code could become a mess.
#
# For the sake of it, let's add another change...

# Starting from `2020-08-01` we would like to price rentals on a per-minute
# basis. Lets consider a very simplistic version for this. The price per
# minute will simply be the price per day divided by the number of minutes in
# a day.
#
# Looking at the whole `Rental` class, we now have something pretty big
# (apologies for the magic-numbers).

Rental = Struct.new(:car, :period, :selected_at, keyword_init: true) do
  attr_reader :car_price_per_day

  DISCOUNT_APPLY_AFTER = Time.utc(2020, 6, 1)
  PRICE_PER_MINUTE_APPLY_AFTER = Time.utc(2020, 8, 1)

  def initialize(*)
    super
    @car_price_per_day = car.price_per_day
  end

  def price
    base_price =
      if selected_at >= PRICE_PER_MINUTE_APPLY_AFTER
        duration_in_minutes * car_price_per_minute
      else
        duration * car_price_per_day
      end

    base_price * (1 - discount)
  end

  def discount
    if selected_at >= DISCOUNT_APPLY_AFTER
      (2 * duration - 4).clamp(0, 40) / 100.0
    else
      0.0
    end
  end

  def duration
    1 + (period.end_on - period.start_on).to_i
  end

  def duration_in_minutes
    (period.end_at.to_i - period.start_at.to_i) / 60.0
  end

  def car_price_per_minute
    car_price_per_day / (24.0 * 60.0)
  end
end

# This will lead to different results that combines each other depending on the
# `selected_at` value.

price_for_3_days.call(Time.utc(2020, 4, 15))  # => 90.0
price_for_3_days.call(Time.utc(2020, 6, 15))  # => 88.2 (2% discount)
price_for_3_days.call(Time.utc(2020, 8, 15))  # => 63.7 (2% discount on 52h)

# ---
#
# At that point, extracting that pricing logic into a separate so-called
# _"service object"_. Since our `Rental` class is only doing that, it would only
# move complexity from a file to another.

# Instead, we could see the computation of the price as a set of _Rules_
# applying themselves to a _Context_. I added a couple of helpers based on the
# assumption the context will respond to `#key?`, `#fetch`, and `merge`.

require "forwardable"

Rule = Struct.new(:context, keyword_init: true) do
  extend Forwardable

  def_delegator :@context, :key?, :fetch, :merge!

  def apply!
    raise NotImplementedError
  end
end

# ---
#
# We could group all the Rules related to computing the `Rental#price` into an
# _Engine_. This `RentalPriceEngineEngine` would try to apply all the known
# rules. Each rule would update the `context` if needed.
#
# We need to decide on what's required in the context for all rules to perform
# correctly. We did that already and we needed:
# * the car's price per day,
# * the time the car was selected by a driver, and
# * the period the rental spans on.
#
# We also need to decide on the keys that will stand as the result.

module RentalPriceEngine
  RULES = [
    PricePerMinuteRule,
    PricePerDayRule,
    DiscountRule,
  ].freeze

  def self.compute(context)
    context.fetch_values(:car_price_per_day, :period, :selected_at) do |key|
      raise KeyError, "Key :#{key} is missing from the context"
    end

    RULES.each do |rule|
      rule.new(context).apply!
    end

    context.fetch(:price)
  end
end

# Now we get `Rental#price` by using the engine and feeding it the appropriate
# context.

class Rental
  def price
    RentalPriceEngine.compute(
      car_price_per_day: car_price_per_day,
      selected_at: selected_at,
      period: period,
    )
  end
end

# The last details are now in the implementation of the rules themselves.
#
# We have the same pattern for each rule, and we could create custom `Rule`
# subclasses to centralize the common patterns. For instance, each rule has
# a guard clause then uses `#merge!` to add or overwrite stuff to `context`.

class PricePerDayRule < Rule
  APPLY_STRICTLY_BEFORE = Time.utc(2020, 9, 1)

  def apply!
    return unless fetch(:selected_at) < APPLY_STRICTLY_BEFORE

    merge!(price: fetch(:period).duration_in_days * fetch(:car_price_per_day))
  end
end

class PricePerMinuteRule < Rule
  APPLY_AFTER = PricePerDayRule::APPLY_STRICTLY_BEFORE

  def apply!
    return unless fetch(:selected_at) >= APPLY_AFTER

    car_price_per_minute = fetch(:car_price_per_day) / (24.0 * 60.0)
    merge!(price: fetch(:period).duration_in_minutes * car_price_per_minute)
  end
end

class DiscountRule < Rule
  APPLY_AFTER = Time.utc(2020, 6, 1)

  def apply!
    return unless fetch(:selected_at) >= APPLY_AFTER

    discount = (2 * fetch(:period).duration_in_days - 4).clamp(0, 40)
    merge!(price: fetch(:price) * (1 - discount / 100.0))
  end
end

# I did migrate the duration in the `Period` class at that point.

Period = Struct.new(:start_at, :end_at, keyword_init: true) do
  def duration_in_days
    1 + (end_at.to_date - start_at.to_date).to_i
  end

  def duration_in_minutes
    (end_at.to_i - start_at.to_i) / 60.0
  end
end

# This approach has its flaws. `PricePerDayRule` and `PricePerMinuteRule` aren't
# exactly independent from each other. They serve the same purpose: to add
# `:price` to the context. And, `DiscountRule` assume a `:price` will be in the
# context at the time it is applied, which make the `RentalPriceEngine::RULES`
# order-sensitive.
#
# All those assumptions aren't great but could be addressed, I guess.

# ---
#
# The idea behind this gem would be to provide simple tools to build _engines_
# like this and provide a good excuse to collect use-cases from outside.
