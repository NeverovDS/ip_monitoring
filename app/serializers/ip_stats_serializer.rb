class IpStatsSerializer < BaseSerializer
  private

  def serialize(stats)
    stats.transform_values { |value| value.is_a?(Float) ? value.round(2) : value }
  end
end
