# frozen_string_literal: true

class IpCheckJob
  include Sidekiq::Worker

  def perform(ip_ids)
    ip_pairs   = fetch_ip_pairs(ip_ids)
    addresses  = ip_pairs.map { |_, ip| ip }
    id_map     = build_id_map(ip_pairs)

    records = build_records(check_ips(addresses), id_map)

    insert_records(records)
  end

  private

  def fetch_ip_pairs(ids)
    Ip.where(id: ids).select_map(%i[id ip_address])
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
    now = Time.now

    results.filter_map do |result|
      ip_id = id_map[result[:ip_address]]
      next unless ip_id

      {
        ip_id: ip_id,
        rtt: result[:rtt],
        created_at: now
      }
    end
  end

  def insert_records(records)
    return if records.empty?

    IpCheck.multi_insert(records)
  end
end
