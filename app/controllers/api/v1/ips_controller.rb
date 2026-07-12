module Api
  module V1
    class IpsController < BaseController
      before_action :set_ip, only: %i[show destroy enable disable stats]

      def index
        render json: Ip.all.map { |ip| IpSerializer.new(ip).call }
      end

      def show
        render json: IpSerializer.new(@ip).call
      end

      def create
        ip = Ip.new(ip_params)

        if ip.save
          render json: IpSerializer.new(ip).call, status: :created
        else
          render_error(:validation_error, ip.errors.to_hash, status: :unprocessable_content)
        end
      end

      def destroy
        @ip.destroy
        head :no_content
      end

      def enable
        @ip.update(enabled: true)
        render json: { id: @ip.id, enabled: true }
      end

      def disable
        @ip.update(enabled: false)
        render json: { id: @ip.id, disabled: true }
      end

      def stats
        range = TimeRange.new(time_from: params[:time_from], time_to: params[:time_to])

        unless range.valid?
          return render_error(:validation_error, range.errors.to_hash, status: :unprocessable_content)
        end

        stats = IpStatsService.new(@ip.id, *range.window).call
        render json: IpStatsSerializer.new(stats).call
      end

      private

      def set_ip
        @ip = Ip.find(params[:id])
      end

      def ip_params
        # Top-level keys (not nested under :ip) to keep the original API contract.
        params.permit(:ip_address, :enabled)
      end
    end
  end
end
