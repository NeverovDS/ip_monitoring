# Scheduled fan-out job (runs every minute via sidekiq-cron): slices the
# enabled IPs into batches and enqueues an IpCheckJob per batch.
class IpCheckWorker
  include Sidekiq::Job

  BATCH_SIZE = 10

  def perform
    Ip.enabled.pluck(:id).each_slice(BATCH_SIZE) do |batch|
      IpCheckJob.perform_async(batch)
    end
  end
end
