require "test_helper"

class IpStatusChangeTest < ActiveSupport::TestCase
  setup { Ip.delete_all }

  test "recent returns the newest changes first, capped at 10" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    ip.ip_status_changes.delete_all # drop the row the DB trigger auto-inserted

    now = Time.current
    12.times { |i| ip.ip_status_changes.create!(status: i.even?, created_at: now - i.minutes) }

    recent = ip.ip_status_changes.recent
    assert_equal 10, recent.size
    times = recent.map(&:created_at)
    assert_equal times.sort.reverse, times, "expected newest-first ordering"
  end
end
