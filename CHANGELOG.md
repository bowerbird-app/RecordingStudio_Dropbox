# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-10-23

### Added
- Optional RecordingStudioAttachable add-on. When Attachable is loaded, this gem
  registers a Dropbox upload provider and mounts Chooser bootstrap, connect, and
  the file-list import page at `/recording_studio_attachable/dropbox`. The file
  list uses Attachable's generic remote file browser, including folders.
- `RecordingStudioDropbox.configuration.enabled`, `client_id` (Chooser app key),
  and `page_size`.
- Chooser launcher JavaScript, pinned as `recording_studio_dropbox/dropbox_picker_launcher`.

### Changed
- `RecordingStudioDropbox.register_oauth_provider` now requests
  `files.metadata.read` and `files.content.read`. It no longer requests
  `files.content.write` by default. Hosts can add write (or other scopes)
  with `RecordingStudioDropbox.configure { |config| config.scopes = ... }`.
- RecordingStudioAttachable is optional. The add-on loads only through
  `ActiveSupport.on_load(:recording_studio_attachable)`, and that hook
  raises if the loaded Attachable version is older than `0.21.0`.
- Hosts set Dropbox options through `RecordingStudioDropbox.configure`.
  This gem does not register an Attachable `config.dropbox` adapter.

### Upgrade notes
- Attachable is optional. If you want Chooser and the file-list import page,
  add `recording_studio_attachable` (`>= 0.21.0`, `< 1.0`). Until v0.21.0 is
  tagged, pin git ref `900cc3a169e26f0e4604e1acb3cbc1d81281aa87`. Run Attachable
  install and migrations, and mount its engine.
- Set `RecordingStudioDropbox.configuration.enabled = true` and
  `client_id` to the Dropbox app key used by Chooser. Dummy placeholder values
  such as `dummy-dropbox-client-id` do not count.
- Oauth still uses `credentials.recording_studio_oauth.outbound.dropbox.client_id`
  and `client_secret`. The Chooser app key is `configuration.client_id`.
- If you upload into Dropbox with `Client#upload_file`, set
  `RecordingStudioDropbox.configuration.scopes` (or pass `scopes:` to
  `register_oauth_provider`) so they include `files.content.write`.
- In the Dropbox app console, add this host to Chooser / Saver domains. Allow
  `https://www.dropbox.com/static/api/2/dropins.js` in `script-src` if you use CSP.

## [0.2.0] - 2026-10-22

### Added
- Depends on RecordingStudioOauth (`>= 0.14.1`, `< 1.0`). Hosts should pin git tag `v0.14.1`.
- `RecordingStudioDropbox.register_oauth_provider` registers a Dropbox outbound provider on Oauth (scopes, authorize/token URLs, offline refresh). Defined in this gem, not in Oauth.
- `RecordingStudioDropbox::OauthToken` reads a live token through `RecordingStudioOauth.connection_for(provider:, root:, actor:)`. Oauth refreshes expired tokens. Missing connections, failed refreshes, and revoked rows raise `ReconnectRequired`.
- Dummy app connect, disconnect, and reconnect for Dropbox through Oauth's outbound flow, using a fake test provider (no real Dropbox credentials).

### Upgrade notes
- Add `recording_studio_oauth` (`>= 0.14.1`, `< 1.0`) and pin git tag `v0.14.1`. Run Oauth's install and migrations.
- Set `credentials.recording_studio_oauth.outbound.dropbox.client_id` and `credentials.recording_studio_oauth.outbound.dropbox.client_secret`. Do not commit the values.
- Call `RecordingStudioDropbox.register_oauth_provider` from the host initializer.
- Build the client with `token_provider: RecordingStudioDropbox::OauthToken.new(root:, actor:)`. Callables that return a token still work for tests.
- Dropbox connections are user OAuth. Files are copied into storage; this gem does not link Dropbox files in place.

## [0.1.0] - 2026-10-22

### Added
- `RecordingStudioDropbox::Client` for folder listing with cursor paging, search, fetch_file, download, and upload.
- Chunked Dropbox upload sessions when the body is larger than 8 MiB.
- `RecordingStudioDropbox::AccessToken` (`#call` first, then `#access_token`). This gem does not depend on RecordingStudioOauth.
- Shared public shape with RecordingStudio Google Drive: `search(query:, cursor:, page_size:)` (not folder-scoped; no `path:`), `list(path:, cursor:, page_size:)`, `fetch_file(path:)`, `upload_file(path:, io:)` (no `content_type:`; Dropbox does not use it), `Page = Data.define(:entries, :next_cursor)`, `DownloadedFile = Data.define(:body, :filename, :content_type)`, `RequestError.new(message = nil, status: nil, code: nil)`, `configure` returns the config. Locators stay provider-native: Dropbox `path:` vs Google Drive ids.
- `ReconnectRequired` for HTTP 401, `invalid_grant`, and `expired_access_token`.
- `RequestError` with `status` and `code` (the Dropbox error tag). The message is `error_summary`, not the response body.

### Upgrade notes
- First release. Hosts should depend on git tag `v0.1.0`. Do not add RecordingStudioOauth until that gem ships.
- Pass tokens through `AccessToken`, not a public `TokenProvider` class.
- Failed API calls raise `RequestError`, not `ApiError`. Paging uses `Page` and `cursor:`, not `Listing`. Download bytes are on `body`. `DownloadedFile#content_type` is always `nil`.
- Call `list`, `fetch_file`, and `upload_file(path:, io:)`. There are no `list_folder`, `metadata`, `content:`, or `content_type:` aliases.

[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.1.0
