class IpsController < ApplicationController
  before_action :set_ip, only: %i[edit update destroy enable disable stats summary]

  def index
    @ips = Ip.order(:id)
    @ip  = Ip.new # for the inline "add IP" form
  end

  def new
    @ip = Ip.new
  end

  def create
    @ip = Ip.new(ip_params)

    if @ip.save
      respond_to do |format|
        format.turbo_stream # create.turbo_stream.erb: append row + reset form
        format.html { redirect_to ips_path, notice: "#{@ip.ip_address} added." }
      end
    else
      respond_to do |format|
        # Re-render just the add form (with errors) in place.
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("new_ip_form", partial: "form", locals: { ip: @ip }),
                 status: :unprocessable_content
        end
        format.html do
          @ips = Ip.order(:id)
          render :index, status: :unprocessable_content
        end
      end
    end
  end

  def edit
  end

  def update
    if @ip.update(ip_params)
      # No flash: the inline edit happens inside a Turbo Frame, so a redirect
      # notice would not render here and would linger until the next full load.
      redirect_to ips_path
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @ip.destroy
    respond_to do |format|
      format.turbo_stream # destroy.turbo_stream.erb: remove the row
      format.html { redirect_to ips_path, notice: "#{@ip.ip_address} removed." }
    end
  end

  def enable
    @ip.update(enabled: true)
    redirect_to ips_path, notice: "#{@ip.ip_address} monitoring enabled."
  end

  def disable
    @ip.update(enabled: false)
    redirect_to ips_path, notice: "#{@ip.ip_address} monitoring disabled."
  end

  def stats
    @range = TimeRange.new(time_from: params[:time_from], time_to: params[:time_to])
    @stats = IpStatsService.new(@ip.id, params[:time_from], params[:time_to]).call if @range.valid?
  end

  # Renders only a Turbo Frame with the last-hour RTT summary. The index loads
  # this lazily per row, so the (relatively expensive) stats query runs once per
  # visible row in its own request instead of blocking the main page render.
  def summary
    @stats = IpStatsService.new(@ip.id).call
  end

  private

  def set_ip
    @ip = Ip.find(params[:id])
  end

  def ip_params
    params.require(:ip).permit(:ip_address, :enabled)
  end
end
