This project aims at providing a set of tools to build somehow complex
business processes or rules. It helps when:

* You decided to split the process into smaller parts working together.
* You need to keep the rules evolving while maintaining the old versions.
* You want to persist the rules that lead to the result of a process.
* You want to make your tests independent from your production data.
* You want to introspect what lead to the result of a process.

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

The idea is very similar to function composition or Rack's middlewares.

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
      context[:price]
    end
  end

  class OrderTotal < Brule::Rule
    def apply
      context[:price] = context[:unit_price] * context[:item_count]
    end
  end

  class Discount < Brule::Rule
    def trigger?
      !applicable_discount.nil?
    end

    def apply
      order_value, discount_rate = applicable_discount
      price = context[:price]
      discount_amount = (price * discount_rate).ceil
      context.merge!(
        price: price - discount_amount,
        discount_rate: discount_rate,
        discount_amount: discount_amount,
      )
    end

    private

    def applicable_discount
      config[:rates]
        .sort_by { |order_value, _| order_value * -1 }
        .find    { |order_value, _| order_value <= context[:price] }
    end
  end

  class StateTax < Brule::Rule
    def apply
      price, state = context.fetch_values(:price, :state)
      tax_rate = config[:rates].fetch(state)
      state_tax = (price * tax_rate).ceil
      context.merge!(
        price: price + state_tax,
        state_tax: state_tax,
      )
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

[elephant]: https://docs.google.com/document/d/1Ls6pTmhY_LV8LwFiboUXoFXenXZl0qVZWPZ8J4uoqpI/edit#
