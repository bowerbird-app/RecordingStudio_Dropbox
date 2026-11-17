# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.2] - 2026-11-17

### Changed
- OpenAPI `title` and `summary` for `dropbox.import`, `dropbox.list`, and `dropbox.search` are action-first. MCP shows those titles as written. `dropbox.import` is "Import from Dropbox". `dropbox.list` is "List Dropbox files". `dropbox.search` is "Search Dropbox". Title and summary are the same string. Tool names, parameters, auth, and return shapes are unchanged.

### Upgrade notes
- Bump to `0.6.2`. No Dropbox migration.
- Hosts that showed "Dropbox - Import", "Dropbox - List", or "Dropbox - Search" now show the action-first titles. Call the same tool names.

## [0.6.1] - 2026-11-17

### Changed
- Dummy pins move to Recording Studio `v7.3.0`, Oauth `v0.25.0`, Accessible `v0.45.1`, Admin `v2.18.0`, API `v1.2.1`, Attachable `v0.31.0`, Moveable `v6.0.0`, Trashable `v1.0.1`, Cache `v0.7.0`, Icons `v0.4.0`, and Flatpack `v0.1.377`. Logs `v0.8.0`, Metrics `v0.9.0`, Root Switchable `v0.16.0`, and Site Settings `v0.6.0` stay.
- Dummy Accessible `admin_root_resolver` returns the kept Studio Workspace root.
- Dummy registers `RecordingStudioApi::AdminApi` only when `admin_root_recordable_type_names` is present.
- Dummy turns off API failed-auth rate limiting, matching the other dummy rate-limit switches.
- Dummy locks Puma `8.1.1`.
- `dropbox.list`, `dropbox.search`, and `dropbox.import` descriptions say what the tool does, where each input comes from, what an entry contains, and how the call fails. Tool names, parameters, auth, and return shape are unchanged.

### Upgrade notes
- Bump to `0.6.1`. No Dropbox migration.
- No Dropbox migration. Recording Studio 7.2's `index_rs_events_on_timeline` is optional. Writes do not need it, and this dummy does not copy it.
- Gemspec floors stay Recording Studio `>= 7.0`, `< 8.0` and RecordingStudioOauth `>= 0.22.0`, `< 1.0`.

## [0.6.0] - 2026-11-15

### Changed
- Recording Studio is now `>= 7.0`, `< 8.0`. RecordingStudioOauth is now `>= 0.22.0`, `< 1.0`.
- Dummy and development pins move to Recording Studio `v7.0.0`, Oauth `v0.22.0`, Accessible `v0.44.0`, Admin `v2.16.0`, API `v0.24.0`, Logs `v0.8.0`, Root Switchable `v0.16.0`, Site Settings `v0.6.0`, Attachable `v0.28.0`, Moveable `v5.0.0`, Trashable `v0.17.0`, Metrics `v0.9.0`, Cache `v0.6.3`, Icons `v0.2.1`, and Flatpack `v0.1.376`.
- Dummy seeds create workspace roots with `RecordingStudio.create_root_recording!`. `root_recording_for` only finds a root.
- Dummy `config.authorize_write` allows a write when an actor is present, including a new root where `root_recording` is nil.
- Dummy seeds read kept recordings with `Recording.kept`.
- Dummy copies core migration `20261114090000_add_root_recording_id_to_recording_studio_events`.
- Dummy locks Puma `8.1.0` and msgpack `>= 1.8.7`.

### Upgrade notes
- Bump to `0.6.0`. No Dropbox migration. Do not tag this PR; pin git tag `v0.6.0` when the release is cut.
- Require Recording Studio `>= 7.0`, `< 8.0` and RecordingStudioOauth `>= 0.22.0`, `< 1.0`. A host still on core 6 cannot resolve this version.
- `RecordingStudio.root_recording_for` only finds a root. Create one with `RecordingStudio.create_root_recording!(recordable, actor:)`. Set `config.authorize_write`. The first root is authorized with `root_recording` nil. Do not set `allow_unauthorized_writes`.
- Copy core migration `20261114090000_add_root_recording_id_to_recording_studio_events` before writing events on Recording Studio 7.
- Replace `recording_studio_trashable_kept_sql` with `Recording.kept`.
- Development hosts that match this dummy should pin the tags above.

## [0.5.1] - 2026-11-15

### Changed
- Allow recording_studio < 8.0 (core 7 phase 1).

### Upgrade notes
- Bump to `0.5.1`. No Dropbox migration. Do not tag this PR; pin git tag `v0.5.1` when the release is cut.
- The `recording_studio` floor stays `>= 4.2`. The ceiling is now `< 8.0`, so core 7 can resolve. Dummy pins stay on core 6.x.

## [0.5.0] - 2026-11-12

### Added
- Public API endpoints `dropbox.import`, `dropbox.list`, and `dropbox.search`, registered from this gem with `RecordingStudioApi.register_endpoint`. MCP advertises each as a tool with the same name. Each call is a thin wrapper over existing gem methods (`Attachable::Import.remote_files`, `Client#list`, `Client#search`).
- Authorization is the in-handler Attachable/Accessible upload-role check on the target recording. Download, upload, OAuth connect/disconnect, Chooser bootstrap, and `register_oauth_provider` stay unexposed. A Dropbox reconnect maps to HTTP 401, same as the picker.

### Upgrade notes
- Bump to `0.5.0`. No Dropbox migration. Do not tag this PR; pin git tag `v0.5.0` when the release is cut.
- Hosts that already mount Recording Studio API and Attachable get the endpoints on boot. No extra initializer call. Grant API clients the Accessible upload role (`:edit` by default) on the recording they import onto. `recording_studio_api` stays optional and is not a gemspec dependency.

## [0.4.4] - 2026-11-05

### Changed
- Security lockfile refresh: Rails `8.1.4.1`, rack `3.2.8`, loofah `2.25.3`, nokogiri `1.19.7`, rails-html-sanitizer `1.7.2`. No behavior change.

### Upgrade notes
- Bump to `0.4.4`. No Dropbox migration. Do not tag this PR; pin git tag `v0.4.4` when the release is cut.

## [0.4.3] - 2026-10-29

### Changed
- Dummy install docs show the current gem tag.
- README documents dummy Oauth `v0.20.0` and Attachable `v0.22.0` pins separately from gemspec floors (Oauth `>= 0.17.0`, `< 1.0`; Attachable is optional).
- Dummy config docs show `enabled`, `client_id`, and `scopes`.
- Dummy Postgres defaults are `recording_studio_dropbox_development` and `recording_studio_dropbox_test`.
- Dropbox picker launcher Node harness fails when Node or Attachable is missing.
- Dummy Dropbox tests share one `grant_workspace_access!` helper.

### Upgrade notes
- Bump to `0.4.3`. No Dropbox migration. Do not tag this PR; pin git tag `v0.4.3` when the release is cut.

## [0.4.2] - 2026-10-29

### Changed
- Dummy and development Flatpack pin is `v0.1.329` so Bundler can lock `view_component` `>= 4.14`.

### Upgrade notes
- Bump to `0.4.2`. No Dropbox migration. Pin git tag `v0.4.2`.
- Development hosts that match this dummy should pin Flatpack `v0.1.329`.

## [0.4.1] - 2026-10-27

### Changed
- RecordingStudio is now `>= 4.2`, `< 7` so this gem can install beside 6.1.0.
- Dummy and development pins move to Recording Studio `v6.3.0`, Flatpack `v0.1.327`, Oauth `v0.20.0`, Attachable `v0.22.0`, Root Switchable `v0.11.0`, Cache `v0.6.0`, Metrics `v0.7.0`, and the newest matching 6.x addon tags. Dummy `net-ssh` is `>= 7.3.8`.

### Upgrade notes
- Bump to `0.4.1`. No Dropbox migration. Pin git tag `v0.4.1`.
- Development hosts that match this dummy should pin Recording Studio `v6.3.0` and Flatpack `v0.1.327`.

## [0.4.0] - 2026-10-26

### Changed
- **BREAKING.** `RecordingStudioDropbox.register_oauth_provider` always registers
  the Dropbox outbound provider with `kind: :root`. Passing `kind: :user` does
  not change that.
- RecordingStudioOauth is now `>= 0.17.0`, `< 1.0`. Pin git tag `v0.17.0`.

### Upgrade notes
- Bump to `0.4.0`. No Dropbox migration. Pin git tag `v0.4.0`.
- Pin Oauth git tag `v0.17.0`. Oauth 0.17.0 requires `kind:` on every outbound
  provider. This gem supplies `:root`. Connect with `owner=root` and the
  workspace `root_recording_id`. Root Connect needs the workspace admin role.
  Non-admin uploaders can no longer connect Dropbox themselves.
- **BREAKING.** Existing personal (`owner=user`) Dropbox connections no longer
  work after Oauth 0.17.0. A workspace admin must reconnect Dropbox for the
  workspace. Personal Connect (`owner=user`) is not valid for Dropbox.

## [0.3.1] - 2026-10-26

### Changed
- Dummy Oauth credentials come from `credentials.recording_studio_oauth.outbound.dropbox`.
  Chooser `configuration.client_id` is set separately and is not read from
  `attachable.dropbox` or `DROPBOX_CLIENT_ID` / `DROPBOX_CLIENT_SECRET`.
- Chooser bootstrap probes Oauth `connection_status` / `connection_for`. It does
  not return an access token string.
- `Configuration#inspect` redacts `client_id` (the public Chooser app key).
- Oversized Dropbox files raise one shared `file_too_large_message` from import
  metadata checks and download body limits.
- Development pins: `recording_studio_api` `v0.16.0`, `recording_studio_logs`
  `v0.7.0`, `recording_studio_metrics` `v0.6.1`. Dummy also pins Attachable
  `v0.21.1`. Oauth stays on `v0.15.1`.

### Removed
- Template leftovers: Dropbox migrations generator (this gem has no `db/migrate`),
  unused engine `ApplicationController` and no-op isolated routes, dead
  `install/INSTALL.md`, dummy `hello_controller`, dummy GitHub CI/Dependabot,
  `install_page.html`, Copilot `.github/agents`, and empty dummy `.keep` stubs.
- Stale RuboCop `test/services/**/*` exclusion.

### Upgrade notes
- Bump to `0.3.1`. No migration.
- Host Oauth keys stay `credentials.recording_studio_oauth.outbound.dropbox`.
  Set Chooser `RecordingStudioDropbox.configuration.client_id` in the initializer.
  Do not copy Oauth secrets into `attachable.dropbox` or Dropbox-named ENV vars.
- Pin git tag `v0.3.1`. Development hosts that match this dummy should move API,
  logs, and metrics together as above. Attachable hosts can stay on `0.21.0`;
  dummy uses `0.21.1`.

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
  add `recording_studio_attachable` (`>= 0.21.0`, `< 1.0`). Run Attachable
  install and migrations, and mount its engine.
- Set `RecordingStudioDropbox.configuration.enabled = true` and
  `client_id` to the Dropbox app key used by Chooser. Dummy placeholder values
  such as `dummy-dropbox-client-id` do not count.
- Oauth still uses `credentials.recording_studio_oauth.outbound.dropbox.client_id`
  and `client_secret`. The Chooser app key is `configuration.client_id`.
  `register_oauth_provider` skips only when both Oauth credentials are blank.
  Other Oauth registration errors still raise.
- If you upload into Dropbox with `Client#upload_file`, set
  `RecordingStudioDropbox.configuration.scopes` (or pass `scopes:` to
  `register_oauth_provider`) so they include `files.content.write`.
- In the Dropbox app console, add this host to Chooser / Saver domains. Allow
  `https://www.dropbox.com/static/api/2/dropins.js` in `script-src` if you use CSP.
- RecordingStudioOauth is now `>= 0.15.0`, `< 1.0`. Pin git tag `v0.15.1`.
  Attachable Dropbox connect uses `RecordingStudioOauth.connection_status` and
  `connection_id_for` (including `:needs_reconnect`). Oauth 0.15.1 has no
  migration.

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

[0.4.4]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.4.4
[0.4.3]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.4.3
[0.4.2]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.4.2
[0.4.1]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.4.1
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.4.0
[0.3.1]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.3.1
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_Dropbox/releases/tag/v0.1.0
