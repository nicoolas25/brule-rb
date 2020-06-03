# This example models the calculation of the fees someone would have to pay in
# case she cancels a service that was previously ordered. The result we wish to
# get the amount the client will have to pay if she cancels.
#
# We have two problems here, the first one is to tell if the client have to pay
# something. For that we have a set of exclusions that could cause a
# cancellation fee to be unapplicable:
#
# 1. The order wasn't canceled by the client
# 2. The client canceled soon-enough after the order
# 3. The client canceled early-enough before the service begins
#
# The second problem is to know how much the client will have to pay. It is a
# rate that is part of the term of service, same goes for the soon-enough or
# early-enough concepts.

require 'brule'

module Cancellation
  class Engine < Brule::Engine
    def result
      context.fetch('amount', 0)
    end
  end

  class Exclusion < Brule::Rule
    def apply
      context['exclusions'] ||= []
      context['exclusions'] += [exclusion_name]
    end
  end

  class NotResponsible < Exclusion
    context_reader 'canceled_by', 'client'

    def trigger?
      canceled_by == client
    end
  end

  class RightAfterOrder < Exclusion
    config_reader 'max_hours_after_order'
    context_reader 'ordered_at', 'canceled_at'

    def trigger?
      (ordered_at + (max_hours_after_order * 3600)) <= canceled_at
    end
  end

  class LongBeforeStart < Exclusion
    config_reader 'max_hours_before_start'
    context_reader 'start_at', 'canceled_at'

    def trigger?
      canceled_at <= (start_at - (max_hours_before_start * 3600))
    end
  end

  class CancellationFeeAmount < Brule::Rule
    config_reader 'cancellation_fee_rate'
    context_reader 'order_amount'
    context_writer 'amount'

    def trigger?
      context.fetch('exclusions', []).none?
    end

    def apply?
      self.amount = order_amount * cancellation_fee_rate
    end
  end
end

require 'bigdecimal'
require 'bigdecimal/util'

engine = Cancellation::Engine.new(
  rules: [
    Cancellation::NotResponsible.new,
    Cancellation::RightAfterOrder.new(
      'max_hours_after_order' => 1,
    ),
    Cancellation::LongBeforeStart.new(
      'max_hours_before_start' => 48,
    ),
    Cancellation::CancellationFeeAmount.new(
      'cancellation_fee_rate' => '0.50'.to_d,
    ),
  ],
)

engine.call(
  'client' => 'John Do',
  'ordered_at' => Time.parse('2020-06-01 12:00:00'),
  'order_amount' => '100'.to_d,
  'start_at' => Time.parse('2020-06-01 15:00:00'),
  'canceled_by' => 'John Do',
  'canceled_at' => Time.parse('2020-06-01 12:45:00'),
)
