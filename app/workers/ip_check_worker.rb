# frozen_string_literal: true

class IpCheckWorker
  BATCH_SIZE = 10

  include Sidekiq::Worker

  def perform
    Ip.where(enabled: true).select_map(:id).each_slice(BATCH_SIZE) do |batch|
      IpCheckJob.perform_async(batch)
    end
  end
end
