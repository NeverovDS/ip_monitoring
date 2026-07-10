require "test_helper"
require "turbo/broadcastable/test_helper"

class IpCheckJobTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  setup { Ip.delete_all }

  test "broadcasts a refreshed summary for each checked ip" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    ip.ip_checks.create!(rtt: 10.0, created_at: Time.current)

    assert_turbo_stream_broadcasts("ips", count: 1) do
      IpCheckJob.new.send(:broadcast_summaries, [ip.id])
    end
  end
end
