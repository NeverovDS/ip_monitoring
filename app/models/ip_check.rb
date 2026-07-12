class IpCheck < ApplicationRecord
  belongs_to :ip

  # Checks within a time window, oldest first.
  scope :in_window, ->(from, to) { where(created_at: from..to).order(:created_at) }

  # [created_at, rtt] pairs for charting over a window (keeps the query out of
  # the controller). Call on a scoped relation, e.g. `ip.ip_checks.rtt_points(from, to)`.
  def self.rtt_points(from, to)
    in_window(from, to).pluck(:created_at, :rtt)
  end

  # Aggregate RTT stats for one IP over a time range, in a single query.
  # No enabled-at-check-time filter is needed: IpCheckWorker only ever checks
  # enabled IPs, so every row already belongs to an active period.
  # Kept as SQL because median (PERCENTILE_CONT) and stddev (STDDEV) have no
  # ActiveRecord calculation equivalent — splitting into per-metric calls would
  # mean several queries and still-raw SQL fragments.
  def self.rtt_stats(ip_id, from, to)
    sql = sanitize_sql_array([<<~SQL, { ip_id: ip_id, from: from, to: to }])
      SELECT
        AVG(rtt)                                         AS avg_rtt,
        MIN(rtt)                                         AS min_rtt,
        MAX(rtt)                                         AS max_rtt,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rtt) AS median_rtt,
        STDDEV(rtt)                                      AS std_dev_rtt,
        (COUNT(*) FILTER (WHERE rtt IS NULL)::float / NULLIF(COUNT(*), 0) * 100) AS packet_loss
      FROM ip_checks
      WHERE ip_id = :ip_id
        AND created_at >= :from
        AND created_at <= :to
      HAVING COUNT(*) > 0
    SQL
    connection.select_one(sql)
  end
end
