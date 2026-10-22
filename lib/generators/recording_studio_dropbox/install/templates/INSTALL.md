RecordingStudioDropbox install complete.

1. Review config/initializers/recording_studio_dropbox.rb.
2. Set credentials.recording_studio_oauth.outbound.dropbox.client_id and
   credentials.recording_studio_oauth.outbound.dropbox.client_secret.
3. Mount RecordingStudioOauth and run its install plus migrations.
4. Resolve tokens with RecordingStudioDropbox::OauthToken, then pass that to Client.
