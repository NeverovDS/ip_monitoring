require "test_helper"
require "minitest/mock"

# Hidden test: copied into the sandbox only after the agent has finished.
class EvalDisabledIpTest < ActiveSupport::TestCase
  # Answers like PingCheckerService, with every address reachable, so no real ping goes out.
  FakePinger = Struct.new(:addresses) do
    def call
      addresses.map { |address| { ip_address: address, rtt: 1.0 } }
    end
  end

  setup { Ip.delete_all }

  test "an IP disabled after its batch was queued is not checked" do
    enabled = Ip.create!(ip_address: "8.8.8.8", enabled: true)
    disabled = Ip.create!(ip_address: "1.1.1.1", enabled: false)

    PingCheckerService.stub(:new, ->(addresses) { FakePinger.new(addresses) }) do
      IpCheckJob.new.perform([ enabled.id, disabled.id ])
    end

    assert_equal 1, IpCheck.where(ip_id: enabled.id).count
    assert_equal 0, IpCheck.where(ip_id: disabled.id).count
  end
end
