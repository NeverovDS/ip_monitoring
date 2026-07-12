# Form object (not persisted) that validates the optional time_from/time_to
# query params for the stats endpoint. Replaces the Roda dry-validation
# TimeRangeContract with the ActiveModel equivalent.
class TimeRange
  include ActiveModel::Model

  # Default lookback when "from" (or "to") is omitted. Single source of truth
  # for the stats window — used by the web/API controllers, the summary frame,
  # and the background job (via `TimeRange.new.window`).
  DEFAULT_WINDOW = 1.hour

  attr_accessor :time_from, :time_to

  validate :time_from_is_parseable
  validate :time_to_is_parseable
  validate :from_before_to

  def from
    parse(time_from)
  end

  def to
    parse(time_to)
  end

  # Effective bounds with defaults applied: blank "to" → now, blank "from" →
  # DEFAULT_WINDOW before "to".
  def effective_to
    to || Time.current
  end

  def effective_from
    from || (effective_to - DEFAULT_WINDOW)
  end

  # [from, to] ready to splat into IpStatsService / IpCheck.rtt_points.
  def window
    [effective_from, effective_to]
  end

  private

  # Time.zone.parse accepts both full ISO8601 and the "YYYY-MM-DDTHH:MM"
  # produced by <input type="datetime-local">. Returns nil on unparseable input.
  def parse(value)
    return nil if value.blank?

    Time.zone.parse(value.strip)
  rescue ArgumentError
    nil
  end

  def time_from_is_parseable
    check_parseable(:time_from)
  end

  def time_to_is_parseable
    check_parseable(:time_to)
  end

  def check_parseable(field)
    raw = public_send(field)
    return if raw.blank?

    errors.add(field, "is not a valid date and time") if parse(raw).nil?
  end

  def from_before_to
    return if from.nil? || to.nil?

    errors.add(:time_from, "must be earlier than time_to") if from > to
  end
end
