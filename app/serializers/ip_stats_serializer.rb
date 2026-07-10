class IpStatsSerializer < BaseSerializer
  private

  def serialize(stats)
    stats.transform_values { |v| v.is_a?(Float) ? v.round(2) : v }
  end
end
