class Ip < ApplicationRecord
  # ip_checks and ip_status_changes are removed by the DB foreign keys
  # (ON DELETE CASCADE), so no `dependent:` option is needed here.
  has_many :ip_checks
  has_many :ip_status_changes

  # Reserved / non-routable ranges we refuse to monitor.
  FORBIDDEN_RANGES = %w[
    0.0.0.0/8
    127.0.0.0/8
    169.254.0.0/16
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
    errors.add(:ip_address, "is in a forbidden range") if FORBIDDEN_RANGES.any? { |range| range.include?(ip) }
  rescue ArgumentError
    errors.add(:ip_address, "is not a valid IP address")
  end
end
