class IpSerializer < BaseSerializer
  private

  def serialize(ip)
    {
      id: ip.id,
      ip_address: ip.ip_address,
      enabled: ip.enabled,
      created_at: ip.created_at&.iso8601,
      updated_at: ip.updated_at&.iso8601
    }
  end
end
