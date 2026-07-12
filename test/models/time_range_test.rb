require "test_helper"

class TimeRangeTest < ActiveSupport::TestCase
  test "window defaults to the last DEFAULT_WINDOW when both bounds are blank" do
    freeze_time do
      from, to = TimeRange.new(time_from: "", time_to: "").window
      assert_equal Time.current, to
      assert_equal Time.current - TimeRange::DEFAULT_WINDOW, from
    end
  end

  test "window uses explicit from/to when given" do
    from = "2026-07-01T10:00"
    to   = "2026-07-01T11:00"
    range = TimeRange.new(time_from: from, time_to: to)
    assert_equal Time.zone.parse(from), range.window.first
    assert_equal Time.zone.parse(to),   range.window.last
  end

  test "blank from with explicit to defaults from to DEFAULT_WINDOW before to" do
    to = "2026-07-01T11:00"
    range = TimeRange.new(time_to: to)
    parsed_to = Time.zone.parse(to)
    assert_equal parsed_to, range.effective_to
    assert_equal parsed_to - TimeRange::DEFAULT_WINDOW, range.effective_from
  end

  test "invalid when from is after to" do
    assert_not TimeRange.new(time_from: "2026-07-01T12:00", time_to: "2026-07-01T10:00").valid?
  end
end
