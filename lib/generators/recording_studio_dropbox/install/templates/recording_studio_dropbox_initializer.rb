# frozen_string_literal: true

RecordingStudioDropbox.configure do |config|
  config.enabled = false
  config.client_id = nil
  config.page_size = 25
end

RecordingStudioDropbox.register_oauth_provider
