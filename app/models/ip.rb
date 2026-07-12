class Ip < ApplicationRecord
  # dependent: :delete_all so `collection.delete_all` issues a real DELETE — the
  # Rails default nullifies ip_id, which the NOT NULL column rejects. The DB also
  # has ON DELETE CASCADE as a backstop for deletes that bypass Active Record.
  has_many :ip_checks, dependent: :delete_all
  has_many :ip_status_changes, dependent: :delete_all

  # Reserved / non-routable IPv4 ranges we refuse to monitor: "this network",
  # loopback, link-local (incl. the cloud metadata endpoint), RFC1918 private
  # ranges, multicast, and limited broadcast.
  FORBIDDEN_RANGES = %w[
    0.0.0.0/8
    10.0.0.0/8
    127.0.0.0/8
    169.254.0.0/16
    172.16.0.0/12
    192.168.0.0/16
    224.0.0.0/4
    255.255.255.255
  ].map { |range| IPAddress(range) }.freeze

  validates :ip_address, uniqueness: true, if: -> { ip_address.present? }
  validate :ip_address_must_be_valid_and_allowed

  scope :enabled, -> { where(enabled: true) }

  private

  def ip_address_must_be_valid_and_allowed
    # The `inet` column silently casts an unparseable string to nil on
    # assignment, so check the raw input to tell "blank" from "invalid".
    raw = ip_address_before_type_cast

    if raw.blank?
      errors.add(:ip_address, "can't be blank")
      return
    end

    if ip_address.blank?
      errors.add(:ip_address, "is not a valid IP address")
      return
    end

    ip = IPAddress(ip_address.to_s)

    # IPv4 only: the forbidden ranges and the ping checker are IPv4-based, and
    # comparing an IPv6 address against an IPv4 range raises inside the
    # ipaddress gem. Reject IPv6 explicitly instead of crashing.
    unless ip.ipv4?
      errors.add(:ip_address, "must be an IPv4 address")
      return
    end

    errors.add(:ip_address, "is in a forbidden range") if FORBIDDEN_RANGES.any? { |range| range.include?(ip) }
  rescue ArgumentError
    errors.add(:ip_address, "is not a valid IP address")
  end
end
