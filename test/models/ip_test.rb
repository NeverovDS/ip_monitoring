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

  test "destroying an ip removes its dependent checks and status changes" do
    ip = Ip.create!(ip_address: "8.8.8.8", enabled: true) # trigger records a status change
    ip.ip_checks.create!(rtt: 5, created_at: Time.current)
    assert ip.ip_checks.exists?
    assert ip.ip_status_changes.exists?

    ip.destroy

    assert_equal 0, IpCheck.where(ip_id: ip.id).count
    assert_equal 0, IpStatusChange.where(ip_id: ip.id).count
  end

  test "collection.delete_all deletes rows (not nullify, which NOT NULL rejects)" do
    ip = Ip.create!(ip_address: "8.8.8.8", enabled: true)
    ip.ip_checks.create!(rtt: 5, created_at: Time.current)

    assert_nothing_raised { ip.ip_checks.delete_all }
    assert_nothing_raised { ip.ip_status_changes.delete_all }
    assert_equal 0, ip.ip_checks.reload.count
    assert_equal 0, ip.ip_status_changes.reload.count
  end
end
