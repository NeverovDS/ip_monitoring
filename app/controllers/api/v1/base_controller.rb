module Api
  module V1
    # Lightweight base for the JSON API: ActionController::API drops the
    # view/cookie/flash middleware the HTML controllers need. Error handling
    # is centralised with rescue_from instead of Roda's single `error` block.
    class BaseController < ActionController::API
      # ActionController::API is stripped down and does not ship the Basic-auth
      # helpers that ActionController::Base includes, so pull them in here.
      include ActionController::HttpAuthentication::Basic::ControllerMethods
      include BasicAuthenticatable

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActionDispatch::Http::Parameters::ParseError, with: :bad_request

      private

      def not_found
        render_error(:not_found, "Resource not found", status: :not_found)
      end

      def bad_request
        render_error(:bad_request, "Invalid JSON", status: :bad_request)
      end

      def render_error(code, message, status:)
        render json: ErrorSerializer.new(code: code, message: message).call, status: status
      end
    end
  end
end
