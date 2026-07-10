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

  test "create via turbo stream appends the row and resets the form" do
    assert_difference -> { Ip.count }, 1 do
      post ips_path, params: { ip: { ip_address: "1.1.1.1" } }, as: :turbo_stream, headers: AUTH
    end
    assert_response :ok
    assert_select "turbo-stream[action=append][target=ips]"
    assert_select "turbo-stream[action=update][target=new_ip_form]"
  end

  test "invalid create via turbo stream re-renders the form with errors" do
    post ips_path, params: { ip: { ip_address: "not-an-ip" } }, as: :turbo_stream, headers: AUTH
    assert_response :unprocessable_content
    assert_select "turbo-stream[action=update][target=new_ip_form]"
  end

  test "destroy via turbo stream removes the row" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    delete ip_path(ip), as: :turbo_stream, headers: AUTH
    assert_response :ok
    assert_select "turbo-stream[action=remove][target=?]", "ip_#{ip.id}"
  end

  test "edit renders an inline form in the address frame" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    get edit_ip_path(ip), headers: AUTH
    assert_response :ok
    assert_select "turbo-frame#address_ip_#{ip.id} form input[name=?]", "ip[ip_address]"
  end

  test "update changes the ip and redirects" do
    ip = Ip.create!(ip_address: "8.8.8.8")
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

  test "summary returns a turbo frame for the row" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    get summary_ip_path(ip), headers: AUTH
    assert_response :ok
    assert_select "turbo-frame#stats_ip_#{ip.id}"
  end

  test "stats page renders" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    get stats_ip_path(ip), headers: AUTH
    assert_response :ok
    assert_select "h1", /Stats/
  end

  test "stats page handles a submitted-but-empty range" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    # The form always submits time_from/time_to, as empty strings when unfilled.
    get stats_ip_path(ip), params: { time_from: "", time_to: "", commit: "Apply" }, headers: AUTH
    assert_response :ok
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
