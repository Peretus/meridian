class RateLimiter
  def initialize(requests_per_second)
    @interval = 1.0 / requests_per_second
    @last_request = Time.now - @interval # Allow first request immediately
    @mutex = Mutex.new
  end

  def wait
    @mutex.synchronize do
      now = Time.now
      elapsed = now - @last_request
      
      if elapsed < @interval
        sleep_time = @interval - elapsed
        sleep(sleep_time)
      end
      
      @last_request = Time.now
    end
  end
end 