require "time"

# Computes availability statistics (RTT avg/min/max/median/stddev and packet
# loss) for one IP over a time range. The query is intentionally raw SQL: it
# uses PERCENTILE_CONT and a correlated "was the IP enabled at check time"
# subquery that would be far less readable expressed through ActiveRecord.
class IpStatsService
  DEFAULT_RANGE = 3600 # seconds

  def initialize(ip_id, time_from = nil, time_to = nil)
    @ip_id     = ip_id
    @time_to   = parse_time_to(time_to)
    @time_from = parse_time_from(time_from)
  end

  def call
    stats = fetch_stats
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

  def fetch_stats
    sql = ActiveRecord::Base.sanitize_sql_array(
      [stats_query, { ip_id: @ip_id, time_from: @time_from, time_to: @time_to }]
    )
    ActiveRecord::Base.connection.select_one(sql)
  end

  def empty_result
    { error: "No data available for the specified period" }
  end

  def round_stats(stats)
    stats.transform_values { |value| value&.round(2) }
  end

  def stats_query
    <<~SQL
      SELECT
        AVG(rtt) AS avg_rtt,
        MIN(rtt) AS min_rtt,
        MAX(rtt) AS max_rtt,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rtt) AS median_rtt,
        STDDEV(rtt) AS std_dev_rtt,
        (COUNT(CASE WHEN rtt IS NULL THEN 1 END)::float / NULLIF(COUNT(*), 0) * 100) AS packet_loss
      FROM ip_checks ic
      WHERE ic.ip_id = :ip_id
        AND ic.created_at >= :time_from
        AND ic.created_at <= :time_to
        AND EXISTS (
          SELECT 1
          FROM ip_status_changes isc
          WHERE isc.ip_id = ic.ip_id
            AND isc.created_at <= ic.created_at
            AND isc.status = TRUE
            AND NOT EXISTS (
              SELECT 1
              FROM ip_status_changes isc2
              WHERE isc2.ip_id = isc.ip_id
                AND isc2.created_at > isc.created_at
                AND isc2.created_at <= ic.created_at
                AND isc2.status = FALSE
            )
        )
      HAVING COUNT(*) > 0;
    SQL
  end
end
