require "test_helper"

class IpCheckTest < ActiveSupport::TestCase
  setup { Ip.delete_all }

  test "in_window returns only checks inside the window, oldest first" do
    ip  = Ip.create!(ip_address: "8.8.8.8")
    now = Time.current
    ip.ip_checks.create!(rtt: 5, created_at: now - 2.hours)    # outside
    mid = ip.ip_checks.create!(rtt: 6, created_at: now - 30.minutes)
    new = ip.ip_checks.create!(rtt: 7, created_at: now - 5.minutes)

    result = ip.ip_checks.in_window(now - 1.hour, now)
    assert_equal [mid.id, new.id], result.map(&:id)
  end

  test "rtt_points returns [created_at, rtt] pairs in window, oldest first" do
    ip  = Ip.create!(ip_address: "8.8.8.8")
    now = Time.current
    ip.ip_checks.create!(rtt: 6, created_at: now - 30.minutes)
    ip.ip_checks.create!(rtt: 7, created_at: now - 5.minutes)
    ip.ip_checks.create!(rtt: 9, created_at: now - 2.hours)    # outside

    points = ip.ip_checks.rtt_points(now - 1.hour, now)
    assert_equal 2, points.size
    assert_equal [6.0, 7.0], points.map { |_t, rtt| rtt.to_f }
    assert points.first.first < points.last.first, "expected points ordered by time ascending"
  end
end
