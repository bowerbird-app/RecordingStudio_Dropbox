# frozen_string_literal: true

RecordingStudioDropbox.configure

require Rails.root.join("app/models/fake_dropbox_oauth")

RecordingStudioDropbox.register_oauth_provider(
  authorize_url: "/fake_oauth/authorize",
  token_url: "/fake_oauth/token",
  revoke_url: "/fake_oauth/revoke",
  client_id: FakeDropboxOauth::CLIENT_ID,
  client_secret: FakeDropboxOauth::CLIENT_SECRET,
  http: FakeDropboxOauth
)
