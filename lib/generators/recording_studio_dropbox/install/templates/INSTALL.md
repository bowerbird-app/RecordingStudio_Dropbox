RecordingStudioDropbox install complete.

1. Review config/initializers/recording_studio_dropbox.rb.
2. Set credentials.recording_studio_oauth.outbound.dropbox.client_id and
   credentials.recording_studio_oauth.outbound.dropbox.client_secret.
3. For the Chooser, set RecordingStudioDropbox.configuration.client_id to the
   Dropbox app key and set enabled to true.
4. Mount RecordingStudioOauth and RecordingStudioAttachable. Run Oauth and
   Attachable install plus migrations.
5. Resolve tokens with RecordingStudioDropbox::OauthToken, then pass that to Client.
   Oauth registration uses files.metadata.read and files.content.read.
   Override scopes with RecordingStudioDropbox.configuration.scopes if you
   need files.content.write.
