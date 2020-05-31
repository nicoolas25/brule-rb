require 'bigdecimal'
require 'bigdecimal/util'
require 'brule'

# In this example, I would like to build a pricing engine for a company.
# That company ships stuff to customer in various states.
#
# This is heavily inspired by the elephant carpaccio kata.
module Pricing
  class Engine < Brule::Engine
    # We start by defining what the engine should produce from its set of rules.
    # Here we'll extract the 'price' from the resulting context and that price
    # will be what that engine will return when called.
    def result
      context.fetch('price')
    end
  end

  # Then we have the rules forming the engine. Those rule will collaborate in
  # order to compute the final 'price'.

  class OrderTotal < Brule::Rule
    # Some writer and reader methods are defined to better manipulate the
    # context. Those are optional, `context` is accessible in the instance.
    # Those helpers assumes the context quacks like a `Hash`.
    context_reader 'unit_price', 'item_count'
    context_writer 'price'

    # OrderTotal will set the price as the 'unit_price' times the 'item_count'.
    def apply
      self.price = unit_price * item_count
    end
  end

  class Discount < Brule::Rule
    # As for the context, the `config_reader` helper is available to quickly
    # access fields from the config. Again, this assumes the rule's config is
    # a `Hash` (or quacks like one).
    config_reader 'rates'
    context_accessor 'price', 'discount_rate', 'discount_amount'

    # If there is no applicable discount, that rule shouldn't be applied.
    def trigger?
      !applicable_discount.nil?
    end

    # Discount subtracts a discount from price depending on discount rates.
    def apply
      self.discount_rate = applicable_discount.last
      self.discount_amount = (price * discount_rate).ceil
      self.price = price - discount_amount
    end

    private

    def applicable_discount
      rates
        .sort_by { |order_value, _| order_value * -1 }
        .find    { |order_value, _| order_value <= price }
    end
  end

  class StateTax < Brule::Rule
    config_reader 'rates'
    context_reader 'state'
    context_accessor 'price', 'state_tax'

    # StateTax will increase the price with the appropriate tax rates. It will
    # track, in the context, the part of the price that was actually due to the
    # taxes. This could be useful for debugging or to build more complex results
    # in the engine.
    def apply
      tax_rate = rates.fetch(state)
      self.state_tax = (price * tax_rate).ceil
      self.price = price + state_tax
    end
  end
end

# At that point, an engine could be instaciated with the rules we defined.

engine = Pricing::Engine.new(
  rules: [
    Pricing::OrderTotal.new,
    Pricing::Discount.new(
      # The configuration of the rules can come from many sources. They could
      # be hardcoded in the code, answer to some selection logic, or they could
      # come from the database.
      'rates' => [
        [  1_000_00, '0.03'.to_d ],
        [  5_000_00, '0.05'.to_d ],
        [  7_000_00, '0.07'.to_d ],
        [ 10_000_00, '0.10'.to_d ],
        [ 50_000_00, '0.15'.to_d ],
      ],
    ),
    Pricing::StateTax.new(
      'rates' => {
        'UT' => '0.0685'.to_d,
        'NV' => '0.0800'.to_d,
        'TX' => '0.0625'.to_d,
        'AL' => '0.0400'.to_d,
        'CA' => '0.0825'.to_d,
      },
    ),
  ],
)

# The engine will run its rules within a context. That context will be passed
# be updated by each rule. The expected class for a context is a `Hash`.
context = {
  'item_count' => 100,
  'unit_price' => 100_00,
  'state' => 'NV',
}

# Finally, we can call the engine with a given context to get the result.
# An engine could be called on many contexts and you won't need to rebuild an
# engine and its rules everytime you need a result.
result = engine.call(context) # => 9_720_00 ($9,720.00)

# The engine allows to access the context to introspect what the rules have done
# with it.
engine.context.fetch_values(
  'discount_rate',             # =>      0.1 (10%)
  'discount_amount',           # => 1_000_00 ($1,000.00)
  'state_tax',                 # =>   720_00 ($720.00)
)

# A more in-depth way to introspect is to look at the the history.
# It returns the rules that were applied and the value for the key at each step.
engine.history(key: 'price').map(&:last) # => [nil, 10_000_00, 9_000_00, 9_720_00]

# One of the goals for that pattern is to make it easy to version an engine. To
# do that, it is either possible to change the configuration of the rules that
# are use within an engine or to change the rules themselves, using different
# classes.
#
# For instance, if we wanted to have taxes for 2020 and taxes for 2021, changing
# only the configuration would work. If we wanted to replace the flat discount
# rates by something more complex, then creating a new rule would be more
# appropriate than playing with the configuration, the context or the rule.
#
# Creating new rules shields the new behaviors from the complexity of the old
# ones. It is useful when the time of removing those old behaviors will come.
# For instance, once all order using the old discount logic are settled, we may
# decide to deprecate, even remove the old rule. In the meantime, the new
# behavior isn't cluttered with weird conditionals and soon-to-be dead code.

# Now, in order to use multiple pricing strategies, over time, for A/B testing
# or for any other purpose, one could persist the engine. The engine by itself
# isn't useful, it need to be associated to an `Order`.

class Order
  attr_reader :id, :item_count, :unit_price, :state, :pricing_engine
  attr_writer :id

  def initialize(attributes)
    @item_count = attributes.fetch(:item_count)
    @unit_price = attributes.fetch(:unit_price)
    @state = attributes.fetch(:state)

    @pricing_engine = attributes.fetch(:pricing_engine)
    @price = attributes.fetch(:price, nil)
    @id = attributes.fetch(:id, nil)
  end

  # The interesting part is this one, either we get the price of the order or
  # we compute the price using the pricing_engine. If we persist the price, then
  # we can run consistency checks between `price` and `computed_price` as they
  # should be the same.
  def price
    @price ||= computed_price
  end

  def computed_price
    @pricing_engine.call(
      'item_count' => @item_count,
      'unit_price' => @unit_price,
      'state' => @state,
    )
  end
end

# Now, we would like to persist such an order. To do that we'll create a
# `Persistance` module that will be in charge to store and retrieve those
# orders.
#
# We'll need a database, here the example is using the awesome Sequel to
# get an in-memory SQLite databse.

require 'sequel'
require 'sqlite3'

DB = Sequel.sqlite

DB.create_table :orders do
  primary_key :id, type: 'integer'

  # Fields denormalizing the context
  column :item_count,        'integer',    null: false
  column :unit_price,        'integer',    null: false
  column :state,             'varchar(3)', null: false

  column :pricing_engine_id, 'integer',    null: false
  column :price,             'integer',    null: false
end

DB.create_table :pricing_engines do
  primary_key :id, type: 'integer'
  column :engine_json, 'text', null: false
end

# We'll serialize the engine using JSON.
require 'json/add/bigdecimal'
require 'json'

module Persistance
  # Both `Persistance::Order` and `Persistance::PricingEngine` are pretty
  # basic. They do persist and retrieve stuff using an ID.
  module Order
    module_function

    Dataset = DB[:orders]

    def persist(order)
      return order.id if order.id

      # The order module take care of the `PricingEngine` persistance.
      order.id = Dataset.insert(
        item_count: order.item_count,
        unit_price: order.unit_price,
        state: order.state,
        pricing_engine_id: PricingEngine.persist(order.pricing_engine),
        price: order.price,
      )
    end

    def retrieve(order_id)
      record = Dataset.first(id: order_id)
      ::Order.new(
        id: record[:id],
        item_count: record[:item_count],
        unit_price: record[:unit_price],
        state: record[:state],
        pricing_engine: PricingEngine.retrieve(record[:pricing_engine_id]),
        price: record[:price],
      )
    end
  end

  module PricingEngine
    module_function

    Dataset = DB[:pricing_engines]

    def persist(engine)
      engine_json = engine.to_hash.to_json
      record = Dataset.first(engine_json: engine_json)
      record && record[:id] || Dataset.insert(engine_json: engine_json)
    end

    def retrieve(engine_id)
      engine_json = Dataset.first(id: engine_id).fetch(:engine_json)
      engine_hash = JSON.load(engine_json)
      Brule::Engine.from_hash(engine_hash)
    end
  end
end

# Staring from the begining, we can create an order, with an engine.

order_1 = Order.new(
  item_count: 100,
  unit_price: 100_00,
  state: 'NV',
  pricing_engine: Pricing::Engine.new(
    rules: [
      Pricing::OrderTotal.new,
      Pricing::Discount.new(
        'rates' => [
          [ 1_000_00, '0.03'.to_d],
          [ 5_000_00, '0.05'.to_d],
          [ 7_000_00, '0.07'.to_d],
          [10_000_00, '0.10'.to_d],
          [50_000_00, '0.15'.to_d],
        ],
      ),
      Pricing::StateTax.new(
        'rates' => {
          'UT' => '0.0685'.to_d,
          'NV' => '0.0800'.to_d,
          'TX' => '0.0625'.to_d,
          'AL' => '0.0400'.to_d,
          'CA' => '0.0825'.to_d,
        },
      ),
    ],
  ),
)

# Then, we persist that order ang fetch it back, the `price` and the
# `computed_price` are the same!

order_id = Persistance::Order.persist(order_1)
order_2 = Persistance::Order.retrieve(order_id)

# We did a roundtrip to the database and we got back a similar order, including
# an identical engine as the original one.
order_1.computed_price == order_2.computed_price &&
  order_1.price == order_1.computed_price &&
  order_2.price == order_2.computed_price

# Each order could persist its engine in order to be able to reproduce the same
# logic, even if that logic isn't the most up to date. As I mentioned this is
# pretty useful to do A/B testing or to cleanly maintain some logic that must
# be kept workign over time.
