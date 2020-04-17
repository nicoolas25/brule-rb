# Anthony decribed a part of its subscription system that does the pricing
# for its self-service music studio business. They have a set of constraints
# that must be satisfied in order to get, or not, a prefered pricing.
#
# Constraints are:
# 1. on the hours (ie: from 10am to 8pm),
# 2. on the days (ie: `mon`, `tue`, ..., `sat`, and/or `sun`),
# 3. on the frequency (ie: up to 4 hours per week)
# 4. on the spreading (ie: can, or cannot, split its quota of hours), and
# 5. on the location (ie: only certain studio).

# A `Plan` holds the constraints details but before going there, we need to
# represent the various values being part of the constraints.

DAYS = [
  SUN = 0b0000001,
  MON = 0b0000010,
  TUE = 0b0000100,
  WED = 0b0001000,
  THU = 0b0010000,
  FRI = 0b0100000,
  SAT = 0b1000000,
]

DAY_HOURS = (0..23).to_a

SPREADINGS = %i[consecutive split]

PERIODICITIES = %i[daily weekly monthly]

Frequency = Struct.new(:amount_of_hours, :periodicity, keyword_init: true)

# The constraint on the location imply constraints on the studio. A `Studio` has
# an unique identifier, a type, and a place. Each attribute will be a `String`.

Studio = Struct.new(:id, :type, :place, keyword_init: true)

# This helps defining the scope required for the location constraint.

SCOPES = %i[id type place]

Location = Struct.new(:scope, :reference, keyword_init: true)

# With those values, we can envision a `Plan` class, holding the logic telling
# if a prefered pricing must apply.

Plan = Struct.new(:days, :hours, :frequency, :spreading, :scope, keyword_init: true)

# Instanciating a `Plan` could look like this:

Plan.new(
  days: SUN | SAT,                                # Week-ends only
  hours: [0, 1, 2, 3, 4, 18, 19, 20, 21, 22, 23], # Evenings only
  frequency: Frequency.new(                       # 4-hours per week
    amount_of_hours: 4,
    periodicity: :weekly,
  ),
  spreading: :split,                              # Hours can be split
  scope: [                                        # Small studios (< 20 m²)
    Location.new(
      scope: :type,
      reference: "small",
    ),
  ],
)

# After that, an algorithm could tell if the plan can be used for a
# `Reservation`. A reservation can be summarized by a studio for period of time.
# To tell if a candidate plan could apply, the `Resevation#can_use_plan?` method
# will also need, a reservation `history` and a candidate `plan` to test
# against.

Period = Struct.new(:start_at, :end_at, keyword_init: true)

Reservation = Struct.new(:studio, :period, keyword_init: true) do
  def can_use_plan?(plan:, history:)
    false
  end
end

# Now to implement `#can_use_plan?` we need to ensure all constraints are
# satisfied.

class Reservation
  def can_use_plan?(plan:, history:)
    if (days & period.start_day) == 0
      return false # Must be in the allowed days
    end

    if !period.covered_hours.all? { |hour| hours.include?(hour) }
      return false # Must be in the allowed hours
    end

    if !scope.all? { |location| studio.match?(location) }
      return false # Must be in the allowed scope
    end

    recent_period = frequency.period_before(period.start_at)
    recent_hours = history
      .select { |reservation| reservation.overlap?(relevent_period) }
      .sum(0) { |reservation| reservation.duration_in_hours }

    if spreading == :consecutive && recent_hours.positive?
      return false # Must be consecutive hours over the plan's frequency
    end

    if (period.duration_in_hours + recent_hours) > frequency.amount_of_hours
      return false # Must stay below the amount of hours of the plan
    end

    true
  end
end

# As much work as possible has been offloaded to all collaborators. I'm making
# those rules and assumptions as I go. For instance, I don't handle time zones,
# I expect that the studio would be booked only for full hours, I went for
# sliding windows for the frequency limits, and so on.

class Studio
  def match?(location)
    self[location.scope] == location.reference
  end
end

class Reservation
  def duration_in_hours
    delta_seconds = period.end_at.to_i - period.start_at.to_i
    (delta_seconds / 3600.0).ceil
  end

  def overlap?(other_period)
    period.overlap(other_period)
  end
end

class Frequency
  WINDOWS = {
    daily:        24 * 60 * 60,  # 24 hours
    weekly:   7 * 24 * 60 * 60,  #  7 days
    monthly: 30 * 24 * 60 * 60,  # 30 days
  }

  def period_before(time)
    delta = WINDOWS.fetch(periodicity)
    Period.new(
      start_at: Time.at(time.to_i - delta).utc,
      end_at: time,
    )
  end
end

class Period
  def start_day
    index = start_at.wday
    DAYS[index]
  end

  def covered_hours
    start_ts = start_at.to_i
    end_ts = end_at.to_i
    hour_step = 3600
    start_ts.step(end_ts, hour_step).map { |ts| Time.at(ts).utc.hour }
  end

  def overlap?(other)
    other.end_at > start_at && other.start_at < end_at
  end
end

# ---
#
# Imagine we're starting from an existing from this specification. But, later
# on, we wish to add another constraint. We will have the choice to make `Plan`
# to take one more field and to not use that field for older plans. That may be
# what already happened with `scope`. If `scope` is empty, then the constraint
# doesn't apply.
#
# Instead of considering all our constraints at once. We can organize them in a
# more structured way. That will have the advantage of splitting the
# `#can_use_plan?` method and be easily extensible in the future.

# A plan becomes a set of constraints.

Plan = Struct.new(:constraints, keyword_init: true)

# And, the `can_use_plan?` reflects that.

class Reservation
  def can_use_plan?(plan:, history:)
    context = { reservation: self, history: history }
    plan.constraints.all? do |constraint|
      constraint.satisfied?(context: context)
    end
  end
end

# The missing piece are obviously the constraints part. From the implementation
# of `#can_use_plan?`, we can guess that the `Plan#constraints` holds a list of
# objects responding to `#satisfied?`.

# Initializing the plan is now a bit different. The rule has been promoted as an
# explicit concept here, it isn't an internal of the `#can_use_plan?` anymore.

frequency = Frequency.new(
  amount_of_hours: 4,
  periodicity: :weekly,
)

Plan.new(constraints: [
  FrequencyRule.new(
    frequency: frequency,
  ),
  DayOfWeekRule.new(
    allowed_days: SUN | SAT,
  ),
  HourOfDayRule.new(
    allowed_hours: [0, 1, 2, 3, 4, 18, 19, 20, 21, 22, 23],
  ),
  ConsecutiveSpreadingRule.new(
    frequency: frequency,
  ),
  LocationRule.new(
    scope: :type,
    reference: "small",
  ),
])

# And the next bit would be to write those rules. Having one class per rule
# gives a new space to put the logic that would only be related to a rule in
# particular.

DayOfWeekRule = Struct.new(:allowed_days, keyword_init: true) do
  def satisfied?(context:)
    reservation_period = context.fetch(:reservation).period
    (allowed_days & reservation_period.start_day) > 0
  end
end

HourOfDayRule = Struct.new(:allowed_hours, keyword_init: true) do
  def satisfied?(context:)
    reservation_period = context.fetch(:reservation).period
    covered_hours(reservation_period).all? do |hour|
      allowed_hours.include?(hour)
    end
  end

  private

  def covered_hours(period)
    start_ts = period.start_at.to_i
    end_ts = period.end_at.to_i
    hour_step = 3600
    start_ts.step(end_ts, hour_step).map { |ts| Time.at(ts).utc.hour }
  end
end

LocationRule = Struct.new(:scope, :reference, keyword_init: true) do
  def satisfied?(context:)
    reservation_studio = context.fetch(:reservation).studio
    reservation_studio[scope] == reference
  end
end

FrequencyRule = Struct.new(:frequency, keyword_init: true) do
  def satisfied?(context:)
    history = context.fetch(:history)
    period = context.fetch(:reservation).period
    recent_hours = recent_hours(prior_to: period, history: history)
    (recent_hours + period.duration_in_hours) <= frequency.amount_of_hours
  end

  private

  def recent_hours(prior_to:, history:)
    recent_period = frequency.period_before(prior_to.start_at)
    history
      .select { |reservation| reservation.overlap?(recent_period) }
      .sum(0) { |reservation| reservation.duration_in_hours }
  end
end

ConsecutiveSpreadingRule = Struct.new(:frequency, keyword_init: true) do
  def satisfied?(context:)
    history = context.fetch(:history)
    period = context.fetch(:reservation).period
    recent_hours(prior_to: period, history: history).zero?
  end

  private

  def recent_hours(prior_to:, history:)
    recent_period = frequency.period_before(prior_to.start_at)
    history
      .select { |reservation| reservation.overlap?(recent_period) }
      .sum(0) { |reservation| reservation.duration_in_hours }
  end
end

# We don't need `Location` anymore. We introduced it to delegate some work to
# them. Those abstraction could be useful but could create a false sense of
# abstraction and attract other usages. The more usages there is, the harder it
# will be to update it. The definition of one method could sightly differ from
# one user to another, forcing us to introduce close and confusing naming or
# complex parameters to change the meaning of a method. All that, depending on
# the context.

# In the example, even `#covered_hours` was taken out of the `Period` class as
# its behavior is a bit too specific to our `HourOfDayRule`. Same for the
# `Studio#match?` method.

# Sadly we already have a bit of duplication around `#recent_hours`. Having this
# shared between rules wouldn't be a problem. A mixin could do that, but you
# would have to do that explicitly.

# ---
#
# From this representation of the plans, we could persist a given plan in a
# serialized way. Having a schema-less representation for constraints is a bit
# scary but opens things up on the versioning side...

# The Plan's serialization will hold references to classes, such as
# `DayOfWeekRule`. It means that it is possible to version not only the
# `allowed_days` but also the class that will manipulate it. We can have
# `DayOfWeekRule::V1` and `DayOfWeekRule::V2` or we can make `DayOfWeekRule`
# support more arguments...

require "sequel"

DB = Sequel.sqlite

DB.create_table :plans do
  primary_key :id, type: "integer"
  column :constraints, "text", null: false
end

class Persitence::Plan
  def insert(plan)
    DB[:plans].insert(constraints: Marshal.dump(plan.constraints))
  end

  def retrieve(plan_id)
    plan_record = DB[:plans].first(id: plan_id)
    constraints = Marshal.load(plan_record.fetch(:constraints))
    Plan.new(constraints: constraints)
  end
end

# Using `Marshal` here is a dangerous choice:
# * it make querying the details of a `Plan` difficult,
# * it forces the _rules_ to be marshal-able (which isn't that bad), and
# * it could have security implications.
#
# I did it for showing an example of persistence but other approaches could
# be better. On the top of my head, I'm thinking about a more explicit
# serialization of the rules and their configurations.
