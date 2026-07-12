require "net/ping"

# Pings a batch of IPs in parallel and returns their round-trip time in ms
# (nil when unreachable). Pure Ruby — carried over from the Roda version
# unchanged, since it has no framework dependencies.
class PingCheckerService
  TIMEOUT = 1
  DEFAULT_THREADS = 25

  def initialize(ip_addresses, thread_count = DEFAULT_THREADS)
    @ip_addresses = Array(ip_addresses)
    @thread_count = thread_count
  end

  def call
    with_thread_pool do |pool|
      execute_promises(build_promises(pool))
    end
  end

  private

  attr_reader :ip_addresses, :thread_count

  def with_thread_pool
    pool = Concurrent::FixedThreadPool.new(thread_count)
    yield(pool)
  ensure
    pool.shutdown
    pool.wait_for_termination
  end

  def build_promises(thread_pool)
    ip_addresses.map do |ip_address|
      Concurrent::Promises.future_on(thread_pool) do
        ping_result(ip_address)
      end
    end
  end

  def ping_result(ip_address)
    ping = Net::Ping::External.new(ip_address, timeout: TIMEOUT)

    start_time = monotonic_time
    success    = ping.ping?

    { ip_address: ip_address, rtt: success ? elapsed_ms(start_time) : nil }
  rescue StandardError
    { ip_address: ip_address, rtt: nil }
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def elapsed_ms(start_time)
    (monotonic_time - start_time) * 1000
  end

  def execute_promises(promises)
    Concurrent::Promises.zip(*promises).value!
  end
end
