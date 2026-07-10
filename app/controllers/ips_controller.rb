class IpsController < ApplicationController
  before_action :set_ip, only: %i[edit update destroy enable disable stats]

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
      redirect_to ips_path, notice: "#{@ip.ip_address} added."
    else
      # Re-render the list with the invalid form (index also renders the form).
      @ips = Ip.order(:id)
      render :index, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @ip.update(ip_params)
      redirect_to ips_path, notice: "#{@ip.ip_address} updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @ip.destroy
    redirect_to ips_path, notice: "#{@ip.ip_address} removed."
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

  private

  def set_ip
    @ip = Ip.find(params[:id])
  end

  def ip_params
    params.require(:ip).permit(:ip_address, :enabled)
  end
end
