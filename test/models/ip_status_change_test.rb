require "test_helper"

class IpStatusChangeTest < ActiveSupport::TestCase
  setup { Ip.delete_all }

  test "recent returns the newest changes first, capped at 10" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    IpStatusChange.where(ip: ip).delete_all # drop the row the DB trigger auto-inserted

    now = Time.current
    # Create via the class with an explicit ip: the association proxy
    # (ip.ip_status_changes.create) intermittently leaves ip_id null here.
    12.times { |i| IpStatusChange.create!(ip: ip, status: i.even?, created_at: now - i.minutes) }

    recent = ip.ip_status_changes.recent
    assert_equal 10, recent.size
    times = recent.map(&:created_at)
    assert_equal times.sort.reverse, times, "expected newest-first ordering"
  end
end
