class IpStatusChange < ApplicationRecord
  # Rows here are inserted by the `ip_status_change_trigger` DB trigger
  # whenever an Ip is created or its `enabled` flag flips — treat as
  # append-only history.
  belongs_to :ip

  # Most-recent status flips first, capped for the stats history panel.
  scope :recent, -> { order(created_at: :desc).limit(10) }
end
