# Pings a batch of IPs and bulk-inserts the results as ip_checks rows.
class IpCheckJob
  include Sidekiq::Job

  def perform(ip_ids)
    ip_pairs  = fetch_ip_pairs(ip_ids)
    addresses = ip_pairs.map { |_id, address| address }
    id_map    = build_id_map(ip_pairs)

    records = build_records(check_ips(addresses), id_map)
    insert_records(records)
  end

  private

  def fetch_ip_pairs(ids)
    # pluck avoids instantiating models; inet values come back as IPAddr,
    # so stringify them to use as ping targets and Hash keys.
    Ip.where(id: ids).pluck(:id, :ip_address).map { |id, address| [id, address.to_s] }
  end

  def build_id_map(ip_pairs)
    ip_pairs.each_with_object({}) do |(id, address), map|
      map[address] = id
    end
  end

  def check_ips(addresses)
    PingCheckerService.new(addresses).call
  end

  def build_records(results, id_map)
    now = Time.current

    results.filter_map do |result|
      ip_id = id_map[result[:ip_address]]
      next unless ip_id

      { ip_id: ip_id, rtt: result[:rtt], created_at: now }
    end
  end

  def insert_records(records)
    return if records.empty?

    # Bulk insert, skipping validations/callbacks (Sequel's multi_insert equivalent).
    IpCheck.insert_all(records)
  end
end
