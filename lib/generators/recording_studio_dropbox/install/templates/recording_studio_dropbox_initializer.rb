# frozen_string_literal: true

RecordingStudioDropbox.configure do |config|
  config.enabled = false
  config.client_id = nil
  config.page_size = 25
  config.scopes = %w[files.metadata.read files.content.read]
  # Add files.content.write if you call Client#upload_file.
end

RecordingStudioDropbox.register_oauth_provider
