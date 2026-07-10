# Form object (not persisted) that validates the optional time_from/time_to
# query params for the stats endpoint. Replaces the Roda dry-validation
# TimeRangeContract with the ActiveModel equivalent.
class TimeRange
  include ActiveModel::Model

  attr_accessor :time_from, :time_to

  validate :time_from_is_iso8601
  validate :time_to_is_iso8601
  validate :from_before_to

  def from
    parse(time_from)
  end

  def to
    parse(time_to)
  end

  private

  def parse(value)
    return nil if value.blank?

    Time.iso8601(value.strip)
  rescue ArgumentError
    nil
  end

  def time_from_is_iso8601
    check_iso8601(:time_from)
  end

  def time_to_is_iso8601
    check_iso8601(:time_to)
  end

  def check_iso8601(field)
    value = public_send(field)
    return if value.blank?

    Time.iso8601(value.strip)
  rescue ArgumentError
    errors.add(field, "must be in ISO8601 format, e.g. 2025-12-04T12:00:00")
  end

  def from_before_to
    return if from.nil? || to.nil?

    errors.add(:time_from, "must be earlier than time_to") if from > to
  end
end
