This project aims at providing a set of tools to build complex and evolving
business rules. It helps when:

* You decided to split the computation into smaller parts working together.
* You need to keep old versions of the rules working.
* You want to persist the rules leading to a result.
* You want to make your tests independent from your production data.
* You want to introspect the computation of a result.

## How does it work

If you use this gem, you'll have a couple of premade elements to build and test
an _engine_ that, given a set of _rules_ and a _context_ will produce a
_result_.

A typical usage for this kind of engine is to use it to compute the price of a
service or a good. But, this is not limited to that use-case as an engine
would be able to produce any kind of results.

An _engine_ orchestrate _rules_ in a way that they would produce enough
information for the engine to assemble a _result_. The rules are arranged in an
ordered sequence and are picked depending on the _context_. Each rule will write
in the context too.

The idea is very similar to function composition or Rack's middlewares. It is a
layering abstraction where each layer works for the next layers in order for the
stack to produce a single value.

## How does it look

Here is an example from the [Elephant Carpaccio][elephant] kata. The specs are:

> Accept 3 inputs from the user:
>
> * How many items
> * Price per item
> * 2-letter state code
>
> Output the total price. Give a discount based on the total price, add state
> tax based on the state and the discounted price.

```ruby
require "brule"

module Pricing
  class Engine < Brule::Engine
    def result
      context.fetch(:price)
    end
  end

  class OrderTotal < Brule::Rule
    context_reader :unit_price, :item_count
    context_writer :price

    def apply
      self.price = unit_price * item_count
    end
  end

  class Discount < Brule::Rule
    config_reader :rates
    context_accessor :price, :discount_rate, :discount_amount

    def trigger?
      !applicable_discount.nil?
    end

    def apply
      self.discount_rate = applicable_discount.last
      self.discount_amount = (price * discount_rate).ceil
      self.price = price - discount_amount
    end

    private

    def applicable_discount
      rates
        .sort_by { |order_value, _| order_value * -1 }
        .find    { |order_value, _| order_value <= context.fetch(:price) }
    end
  end

  class StateTax < Brule::Rule
    config_reader :rates
    context_reader :state
    context_accessor :price, :state_tax

    def apply
      tax_rate = rates.fetch(state)
      self.state_tax = (price * tax_rate).ceil
      self.price = price + state_tax
    end
  end
end

require "bigdecimal"
require "bigdecimal/util"

engine = Pricing::Engine.new(
  rules: [
    Pricing::OrderTotal.new,
    Pricing::Discount.new(
      rates: [
        [  1_000_00, "0.03".to_d ],
        [  5_000_00, "0.05".to_d ],
        [  7_000_00, "0.07".to_d ],
        [ 10_000_00, "0.10".to_d ],
        [ 50_000_00, "0.15".to_d ],
      ],
    ),
    Pricing::StateTax.new(
      rates: {
        "UT" => "0.0685".to_d,
        "NV" => "0.0800".to_d,
        "TX" => "0.0625".to_d,
        "AL" => "0.0400".to_d,
        "CA" => "0.0825".to_d,
      },
    ),
  ],
)

result = engine.call(
  item_count: 100,
  unit_price: 100_00,
  state: "NV",
)

# Access the main result
result                        # => 9_720_00 ($9,720.00)

# Access the context
engine.context.fetch_values(
  :discount_rate,             # =>      0.1 (10%)
  :discount_amount,           # => 1_000_00 ($1,000.00)
  :state_tax,                 # =>   720_00 ($720.00)
)

# Access the history
engine.history(key: :price)   # => [
                              # =>   [:initial,                                nil],
                              # =>   [#<struct Pricing::OrderTotal ...>, 10_000_00],
                              # =>   [#<struct Pricing::Discount ...>,    9_000_00],
                              # =>   [#<struct Pricing::StateTax ...>,    9_720_00],
                              # => ]
```

## What does it bring to the table

If you compare this approach with a simple method like this one:

```ruby
require "bigdecimal"
require "bigdecimal/util"

STATE_TAXES = {
  "UT" => "0.0685".to_d,
  "NV" => "0.0800".to_d,
  "TX" => "0.0625".to_d,
  "AL" => "0.0400".to_d,
  "CA" => "0.0825".to_d,
}

DISCOUNT_RATES = [
  [ 50_000_00, "0.15".to_d ],
  [ 10_000_00, "0.10".to_d ],
  [  7_000_00, "0.07".to_d ],
  [  5_000_00, "0.05".to_d ],
  [  1_000_00, "0.03".to_d ],
  [         0, "0.00".to_d ],
]

def pricing(item_count, unit_price, state)
  price = item_count * unit_price
  discount_rate = DISCOUNT_RATES.find { |limit, _| limit <= price }.last
  state_tax = STATE_TAXES.fetch(state)
  price * (1 - discount_rate) * (1 + state_tax)
end
```

... then you'll find significant differences:

* Over-abstraction versus under-abstraction
  * 1st example uses the layering abstraction provided by the gem
  * 2nd example uses nothing, [YAGNI][yagni]
* Generalization vs specialization
  * 1st approach is more generic and could handle changes
  * 2nd approach is more specialized and would require a rewrite
* Complexity versus brievety
  * 1st example is more verbose and thus is harder to grasp
  * 2nd example is more concise and fits in the head
* Configuration versus constants
  * 1st example relies on rule's configuration
  * 2nd example relies on `STATE_TAXES` and `DISCOUNT_RATES`
* Observability vs black-box
  * 1st example allows to provide more information (`state_tax` and so on)
  * 2nd example only gives a single result
* Data-independent versus hard-coded values
  * 1st example considers as much logic as possible as data
  * 2nd example mixes data and logic together (with hidden dependencies and assumptions)
* Temporal extensibility or versionning
  * 1st example can compute the price using different rules
    * Without discounts or with different discount rate per client
    * With tax rates from on year or another
  * 2nd example will have to introduce options, or even different methods
* Testability
  * 1st example could be tested at various levels without any mocks
  * 2nd example have to mock hidden dependencies from the implementation

Overall, it is about finding the right level of abtsraction. This tiny framework
helps you by providing you a little abstraction. Even if you're not using this
gem directly, it can give you some ideas behind it.

[elephant]: https://docs.google.com/document/d/1Ls6pTmhY_LV8LwFiboUXoFXenXZl0qVZWPZ8J4uoqpI/edit#
[yagni]: https://en.wikipedia.org/wiki/You_aren%27t_gonna_need_it
