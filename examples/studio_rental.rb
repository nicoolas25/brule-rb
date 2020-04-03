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

DAYS = %i[sun mon tue wed thu fri sat]

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
  days: %i[sun sat],                              # Week-ends only
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
    if !days.include?(period.start_day)
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
