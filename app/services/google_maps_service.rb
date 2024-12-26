require 'net/http'
require 'uri'

class GoogleMapsService
  class Error < StandardError; end

  REQUESTS_PER_SECOND = 10

  def initialize
    @api_key = Rails.application.config.google_maps[:api_key]
    raise Error, "Google Maps API key not configured" unless @api_key
    
    # Create a rate limiter for 10 requests per second
    @rate_limiter = RateLimiter.new(REQUESTS_PER_SECOND)
  end

  def fetch_static_map(latitude:, longitude:, zoom: 16, size: "224x224")
    # Wait for rate limit before making request
    @rate_limiter.wait
    
    uri = static_map_uri(latitude: latitude, longitude: longitude, zoom: zoom, size: size)
    response = Net::HTTP.get_response(uri)
    
    if response.is_a?(Net::HTTPSuccess)
      response.body
    else
      raise Error, "Failed to fetch map image: #{response.code} #{response.message}"
    end
  end

  private

  def static_map_uri(latitude:, longitude:, zoom:, size:)
    URI::HTTPS.build(
      host: "maps.googleapis.com",
      path: "/maps/api/staticmap",
      query: {
        center: "#{latitude},#{longitude}",
        zoom: zoom,
        size: size,
        maptype: "satellite",
        key: @api_key
      }.to_query
    )
  end
end 