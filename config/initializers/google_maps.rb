Rails.application.config.google_maps = {
  api_key: Rails.application.credentials.dig(:google_maps, :api_key)
} 