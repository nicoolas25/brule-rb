This project aims at providing a set of tools to build complex and evolving
business rules. It helps when:

* You decided to split the computation into smaller parts working together.
* You need to keep old versions of the rules working.
* You want to persist the rules leading to a result.
* You want to make your tests independent from your production data.
* You want to introspect the computation of a result.

![Test](https://github.com/nicoolas25/brule-rb/workflows/Test/badge.svg?branch=master)

## How does it work

The idea is very similar to function composition or Rack's middlewares. It is a
layering abstraction where each layer works for the next layers in order for the
whole to produce a single result.

An _engine_ respond to `#call`, taking a `context` in argument. It produces a
_result_ that is extracted from the _context_ by the `#result` method. Before
doing that, the engine apply its _rules_.

![Engine](https://github.com/nicoolas25/brule-rb/blob/master/docs/img/engine.png?raw=true)

Each rule have two methods: `#trigger?` and `#apply`. `#apply` runs only when
`trigger?` is true. `#apply` writes stuff to the context for other rules and
for the engine to produce the result. Rules can be initialized with a
_configuration_.

![Rule](https://github.com/nicoolas25/brule-rb/blob/master/docs/img/rule.png?raw=true)


A typical usage for this kind of engine is to use it to compute the price of a
service or a good. But, this is not limited to that use-case as an engine
would be able to produce any kind of results.

## How does it look

[Here](https://nicoolas25.github.io/brule-rb/examples/elephant_carpaccio.html)
is an example from the [Elephant Carpaccio][elephant] kata. The specs are:

> Accept 3 inputs from the user:
>
> * How many items
> * Price per item
> * 2-letter state code
>
> Output the total price. Give a discount based on the total price, add state
> tax based on the state and the discounted price.

[This](https://nicoolas25.github.io/brule-rb/examples/elephant_carpaccio.html)
is the smallest example and the _best_ one to refer to. More examples are
available:

- [Elephant Carpaccio](https://nicoolas25.github.io/brule-rb/examples/elephant_carpaccio.html)
- [Car rental](https://nicoolas25.github.io/brule-rb/examples/car_rental.html)
- [Studio rental](https://nicoolas25.github.io/brule-rb/examples/studio_rental.html)
- [Promo code](https://nicoolas25.github.io/brule-rb/examples/promo_code.html) (WIP)

## What does it bring to the table

If you compare [this approach](https://nicoolas25.github.io/brule-rb/examples/elephant_carpaccio.html)
with a simple method like this one:

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
