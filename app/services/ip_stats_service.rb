require "time"

# Parses the optional time range and returns rounded RTT statistics for one IP
# (the actual aggregate query lives on IpCheck.rtt_stats).
class IpStatsService
  DEFAULT_RANGE = 3600 # seconds

  def initialize(ip_id, time_from = nil, time_to = nil)
    @ip_id     = ip_id
    @time_to   = parse_time_to(time_to)
    @time_from = parse_time_from(time_from)
  end

  def call
    stats = IpCheck.rtt_stats(@ip_id, @time_from, @time_to)
    return empty_result if stats.nil?

    round_stats(stats)
  end

  private

  def parse_time_to(time_to)
    # blank? (not nil?): HTML forms submit empty strings, not nil. Time.zone.parse
    # accepts full ISO8601 and the datetime-local "YYYY-MM-DDTHH:MM" format.
    time_to.blank? ? Time.current : (Time.zone.parse(time_to) || Time.current)
  end

  def parse_time_from(time_from)
    # Subtract seconds (not days): DEFAULT_RANGE is a plain Integer and @time_to
    # is a Time, so this is correct arithmetic.
    default = @time_to - DEFAULT_RANGE
    time_from.blank? ? default : (Time.zone.parse(time_from) || default)
  end

  def empty_result
    { error: "No data available for the specified period" }
  end

  def round_stats(stats)
    stats.transform_values { |value| value&.round(2) }
  end
end
