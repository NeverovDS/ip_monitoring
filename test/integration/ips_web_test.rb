require "test_helper"

class IpsWebTest < ActionDispatch::IntegrationTest
  AUTH = { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin") }.freeze

  setup { Ip.delete_all }

  test "index renders" do
    Ip.create!(ip_address: "8.8.8.8", enabled: true)
    get root_path, headers: AUTH
    assert_response :ok
    assert_select "table.ips"
    assert_select "td.mono", text: "8.8.8.8"
  end

  test "creates an ip and redirects" do
    assert_difference -> { Ip.count }, 1 do
      post ips_path, params: { ip: { ip_address: "1.1.1.1", enabled: "1" } }, headers: AUTH
    end
    assert_redirected_to ips_path
  end

  test "re-renders index with errors on invalid create" do
    post ips_path, params: { ip: { ip_address: "not-an-ip" } }, headers: AUTH
    assert_response :unprocessable_content
    assert_select ".errors"
  end

  test "edit and update" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    get edit_ip_path(ip), headers: AUTH
    assert_response :ok

    patch ip_path(ip), params: { ip: { ip_address: "9.9.9.9" } }, headers: AUTH
    assert_redirected_to ips_path
    assert_equal "9.9.9.9", ip.reload.ip_address.to_s
  end

  test "enable and disable" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    post enable_ip_path(ip), headers: AUTH
    assert ip.reload.enabled
    post disable_ip_path(ip), headers: AUTH
    assert_not ip.reload.enabled
  end

  test "stats page renders" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    get stats_ip_path(ip), headers: AUTH
    assert_response :ok
    assert_select "h1", /Stats/
  end

  test "stats page shows validation error for bad range" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    get stats_ip_path(ip), params: { time_from: "zzz" }, headers: AUTH
    assert_response :ok
    assert_select ".errors"
  end

  test "destroy" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    assert_difference -> { Ip.count }, -1 do
      delete ip_path(ip), headers: AUTH
    end
    assert_redirected_to ips_path
  end
end
