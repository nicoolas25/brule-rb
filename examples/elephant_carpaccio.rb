require 'bigdecimal'
require 'bigdecimal/util'
require 'brule'

module Pricing
  class Engine < Brule::Engine
    def result
      context.fetch('price')
    end
  end

  class OrderTotal < Brule::Rule
    context_reader 'unit_price', 'item_count'
    context_writer 'price'

    def apply
      self.price = unit_price * item_count
    end
  end

  class Discount < Brule::Rule
    config_reader 'rates'
    context_accessor 'price', 'discount_rate', 'discount_amount'

    def trigger?
      !applicable_discount.nil?
    end

    def apply
      self.discount_rate = applicable_discount.last
      self.discount_amount = (price * discount_rate).ceil
      self.price = price - discount_amount
    end

    def self.from_hash(*)
      super do |config_hash|
        { 'rates' => config_hash.fetch('rates').map { |s, r| [s, r.to_d] } }
      end
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

    def apply
      tax_rate = rates.fetch(state)
      self.state_tax = (price * tax_rate).ceil
      self.price = price + state_tax
    end

    def self.from_hash(*)
      super do |config_hash|
        { 'rates' => config_hash.fetch('rates').transform_values(&:to_d) }
      end
    end
  end
end

engine = Pricing::Engine.new(
  rules: [
    Pricing::OrderTotal.new,
    Pricing::Discount.new(
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

context = {
  'item_count' => 100,
  'unit_price' => 100_00,
  'state' => 'NV',
}

result = engine.call(context)

require 'json'
require 'sequel'
require 'sqlite3'

DB = Sequel.sqlite

DB.create_table :pricing_engines do
  primary_key :id, type: 'integer'
  column :engine_json, 'text', null: false
end

module Pricing
  class Persistance
    def insert(engine)
      DB[:pricing_engines].insert(engine_json: engine.to_hash.to_json)
    end

    def retrieve(id)
      engine_json = DB[:pricing_engines].first(id: id).fetch(:engine_json)
      Brule::Engine.from_hash(JSON.parse(engine_json))
    end
  end
end

repository = Pricing::Persistance.new
engine_id = repository.insert(engine)
similar_engine = repository.retrieve(engine_id)

if similar_engine.call(context) != result
  raise "Serialized engine must produce the same result"
else
  puts "Looking good!"
end
