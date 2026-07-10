require "test_helper"

class ApiV1IpsTest < ActionDispatch::IntegrationTest
  AUTH = { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "admin") }.freeze

  setup { Ip.delete_all }

  test "requires basic auth" do
    get "/api/v1/ips"
    assert_response :unauthorized
  end

  test "lists ips" do
    Ip.create!(ip_address: "8.8.8.8")
    get "/api/v1/ips", headers: AUTH
    assert_response :ok
    assert_equal 1, response.parsed_body.size
  end

  test "creates a valid ip" do
    assert_difference -> { Ip.count }, 1 do
      post "/api/v1/ips", params: { ip_address: "8.8.8.8", enabled: true }, as: :json, headers: AUTH
    end
    assert_response :created
    assert_equal "8.8.8.8", response.parsed_body["ip_address"]
  end

  test "rejects an invalid ip" do
    post "/api/v1/ips", params: { ip_address: "not-an-ip" }, as: :json, headers: AUTH
    assert_response :unprocessable_content
  end

  test "rejects a forbidden range" do
    post "/api/v1/ips", params: { ip_address: "127.0.0.1" }, as: :json, headers: AUTH
    assert_response :unprocessable_content
  end

  test "rejects a duplicate ip" do
    Ip.create!(ip_address: "8.8.8.8")
    post "/api/v1/ips", params: { ip_address: "8.8.8.8" }, as: :json, headers: AUTH
    assert_response :unprocessable_content
  end

  test "shows an ip and 404s for a missing one" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    get "/api/v1/ips/#{ip.id}", headers: AUTH
    assert_response :ok

    get "/api/v1/ips/999999", headers: AUTH
    assert_response :not_found
  end

  test "enables and disables an ip" do
    ip = Ip.create!(ip_address: "8.8.8.8")

    post "/api/v1/ips/#{ip.id}/enable", headers: AUTH
    assert_response :ok
    assert ip.reload.enabled

    post "/api/v1/ips/#{ip.id}/disable", headers: AUTH
    assert_response :ok
    assert_not ip.reload.enabled
  end

  test "returns stats and rejects a bad timestamp" do
    ip = Ip.create!(ip_address: "8.8.8.8")

    get "/api/v1/ips/#{ip.id}/stats", headers: AUTH
    assert_response :ok

    get "/api/v1/ips/#{ip.id}/stats", params: { time_from: "zzz" }, headers: AUTH
    assert_response :unprocessable_content
  end

  test "destroys an ip" do
    ip = Ip.create!(ip_address: "8.8.8.8")
    assert_difference -> { Ip.count }, -1 do
      delete "/api/v1/ips/#{ip.id}", headers: AUTH
    end
    assert_response :no_content
  end
end
