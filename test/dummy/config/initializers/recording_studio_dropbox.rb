# frozen_string_literal: true

oauth = begin
  nested = Rails.application.credentials.dig(:recording_studio_oauth, :outbound, :dropbox)
  nested.respond_to?(:to_h) ? nested.to_h.symbolize_keys : {}
rescue ActiveSupport::EncryptedFile::MissingKeyError, Errno::ENOENT, ArgumentError
  {}
end

RecordingStudioDropbox.configure do |config|
  config.enabled = true
  # Chooser app key is public and is not the Oauth client_id.
  config.client_id = "test-dropbox-app-key"
end

client_id = oauth[:client_id].presence
client_secret = oauth[:client_secret].presence
use_fake = Rails.env.test? || client_id.blank? || client_secret.blank?

if use_fake
  require Rails.root.join("app/models/fake_dropbox_oauth")

  RecordingStudioDropbox.register_oauth_provider(
    authorize_url: "/fake_oauth/authorize",
    token_url: "/fake_oauth/token",
    revoke_url: "/fake_oauth/revoke",
    client_id: FakeDropboxOauth::CLIENT_ID,
    client_secret: FakeDropboxOauth::CLIENT_SECRET,
    http: FakeDropboxOauth
  )
else
  RecordingStudioDropbox.register_oauth_provider(
    client_id: client_id,
    client_secret: client_secret
  )
end
