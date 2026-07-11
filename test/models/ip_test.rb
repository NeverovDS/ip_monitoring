require "test_helper"

class IpTest < ActiveSupport::TestCase
  setup { Ip.delete_all }

  test "a valid public IP is accepted" do
    assert Ip.new(ip_address: "8.8.8.8").valid?
  end

  test "requires an IP address" do
    ip = Ip.new(ip_address: "")
    assert_not ip.valid?
    assert_includes ip.errors[:ip_address], "can't be blank"
  end

  test "rejects an unparseable IP" do
    ip = Ip.new(ip_address: "not-an-ip")
    assert_not ip.valid?
    assert_includes ip.errors[:ip_address], "is not a valid IP address"
  end

  test "rejects a reserved/forbidden range" do
    assert_not Ip.new(ip_address: "127.0.0.1").valid?
    assert_not Ip.new(ip_address: "169.254.0.1").valid?
  end

  test "enforces uniqueness of the address" do
    Ip.create!(ip_address: "8.8.8.8")
    dup = Ip.new(ip_address: "8.8.8.8")
    assert_not dup.valid?
    assert_includes dup.errors[:ip_address], "has already been taken"
  end

  test "enabled scope returns only enabled IPs" do
    on = Ip.create!(ip_address: "8.8.8.8", enabled: true)
    Ip.create!(ip_address: "1.1.1.1", enabled: false)
    assert_equal [on], Ip.enabled.to_a
  end
end
