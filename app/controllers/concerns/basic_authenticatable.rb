# Shared HTTP Basic auth for both the HTML and the API controller trees,
# so the credential logic lives in one place.
module BasicAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate
  end

  private

  def authenticate
    authenticate_or_request_with_http_basic("Application") do |username, password|
      expected_user = ENV.fetch("ADMIN_USERNAME", "admin")
      expected_pass = ENV.fetch("ADMIN_PASSWORD", "admin")

      # secure_compare guards against timing attacks; & (not &&) so both
      # comparisons always run in constant time regardless of the first result.
      ActiveSupport::SecurityUtils.secure_compare(username.to_s, expected_user) &
        ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_pass)
    end
  end
end
