# Returns rounded RTT statistics for one IP over an already-resolved time
# window. Parsing/defaulting of the window lives in TimeRange; the aggregate
# query lives in IpCheck.rtt_stats — this object just orchestrates and rounds.
class IpStatsService
  def initialize(ip_id, from, to)
    @ip_id = ip_id
    @from  = from
    @to    = to
  end

  def call
    stats = IpCheck.rtt_stats(@ip_id, @from, @to)
    return empty_result if stats.nil?

    round_stats(stats)
  end

  private

  def empty_result
    { error: "No data available for the specified period" }
  end

  def round_stats(stats)
    stats.transform_values { |value| value&.round(2) }
  end
end
