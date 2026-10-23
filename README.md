# Recording Studio Dropbox

This gem talks to the Dropbox HTTP API for Recording Studio. It lists folders, fetches metadata, downloads files, and uploads files. Files are copied into storage later. This gem does not link Dropbox files in place.

Dropbox uses user OAuth. Tokens live on RecordingStudioOauth outbound connections. When RecordingStudioAttachable is loaded, this gem registers the Dropbox upload provider, Chooser, and file-list import page.

## What you get

`RecordingStudioDropbox::Client` is the public entry. Resolve a token with `RecordingStudioDropbox::OauthToken`, then pass it as `token_provider:`. Tests can still pass a callable.

| Method | Dropbox endpoints |
| --- | --- |
| `list` | `/2/files/list_folder` and `/2/files/list_folder/continue` |
| `search` | `/2/files/search_v2` and `/2/files/search/continue_v2` |
| `fetch_file` | `/2/files/get_metadata` |
| `download` | `/2/files/download` |
| `upload_file` | `/2/files/upload`, or a session (`start`, `append_v2`, `finish`) when the body is larger than 8 MiB |

`list(path:, cursor:, page_size:)` and `search(query:, cursor:, page_size:)` return a `Page` with `entries`, `next_cursor` (nil when there are no more pages), and `more?` (`false` for a nil or empty cursor). Pass `cursor:` to fetch the next page. `search` is not folder-scoped: it has no `path:`. `upload_file(path:, io:)` takes an IO (or a String, the same as Google Drive's `read_io`) and does not take `content_type:`, because Dropbox does not use a MIME type on upload.

Download returns a `DownloadedFile` with `body`, `filename`, and `content_type`. `content_type` is always `nil`, because Dropbox does not give a real MIME type.

HTTP uses `Net::HTTP`, the same client Recording Studio Attachable uses for Dropbox today. There is no Dropbox SDK.

Oauth registration uses `files.metadata.read` and `files.content.read`. Override that default through `RecordingStudioDropbox.configure` if you need more:

```ruby
RecordingStudioDropbox.configure do |config|
  config.scopes = %w[files.metadata.read files.content.read files.content.write]
end
```

`Client#upload_file` still needs `files.content.write` in that list.

## Shared shape with Google Drive

This client uses the same method names as RecordingStudio Google Drive: `list`, `search`, `fetch_file`, `download`, and `upload_file`. Locators stay provider-native. Dropbox takes `path:` (a Dropbox path, or an `id:`, `ns:`, or `rev:` prefix). Google Drive takes Drive ids (`parent_id`, `file_id`). `search` is the same on both gems: query plus cursor paging, not a folder locator. `upload_file` takes `io:` on both. Google Drive also requires `content_type:`; Dropbox omits it because the Dropbox upload API does not use it.

## Oauth tokens

Register the Dropbox provider from this gem, not from Oauth:

```ruby
RecordingStudioDropbox.register_oauth_provider
```

That call uses Oauth's public registry. Authorize and token URLs are Dropbox's. Refresh is on. `token_access_type` is `offline`. If both Oauth `client_id` and `client_secret` are blank, the call skips registration so a generated initializer can boot before credentials exist. It does not rescue other Oauth errors.

Set these credential keys (never commit the values):

- `recording_studio_oauth.outbound.dropbox.client_id`
- `recording_studio_oauth.outbound.dropbox.client_secret`

Resolve a token, then build the client:

```ruby
token = RecordingStudioDropbox::OauthToken.new(
  root: root_recording,
  actor: current_user
)

client = RecordingStudioDropbox::Client.new(token_provider: token)
client.list(path: "")
```

`AccessToken` and callable token providers still work (`Client.new(token_provider:)`).

`OauthToken` calls `RecordingStudioOauth.connection_for(provider:, root:, actor:)`. Oauth refreshes an expired access token. If there is no connection, refresh fails, or the row is revoked, this gem raises `ReconnectRequired`. Tokens never go in the session, logs, or exception messages.

Tests can still pass a callable and stub `Net::HTTP`. They should not hit Dropbox.

`RecordingStudioDropbox::AccessToken.new(provider)` still reads `#call` first, then `#access_token`. A raw String is a misconfiguration and raises `ArgumentError`. A blank or nil token at request time raises `ReconnectRequired`.

`RecordingStudioDropbox.configure` yields the configuration and returns it. Dropbox options live there (`enabled`, `client_id`, `page_size`, `scopes`). Hosts do not set them on Attachable `config.dropbox`.

## Attachable upload add-on

The add-on loads only when `RecordingStudioAttachable` is present. It uses Attachable's public hooks: `ActiveSupport.on_load(:recording_studio_attachable)`, `register_upload_provider`, and `register_adapter_routes(:dropbox)`.

Turn it on in the host initializer. Attachable is optional; skip it if you only need the Dropbox client.

```ruby
RecordingStudioDropbox.configure do |config|
  config.enabled = true
  config.client_id = "your-dropbox-app-key"
  config.page_size = 25
  config.scopes = %w[files.metadata.read files.content.read]
end
```

`enabled` and `client_id` are this gem's settings. `client_id` is the Dropbox app key for Chooser. Dummy values such as `dummy-dropbox-client-id` are ignored. Routes stay at `/recording_studio_attachable/dropbox`.

Connect uses Oauth outbound connections. Imports copy files through `RecordingStudioAttachable::Services::ImportRemoteFiles`. Chooser runs `Dropbox.choose` only from a user click. The file-list page uses Attachable's `providers/_remote_file_browser` for files and folders. Bootstrap `needs_auth` is the auth signal; `connect` is always the connect recipe.

## Errors

Token problems raise `RecordingStudioDropbox::ReconnectRequired`. Callers can turn that into a reconnect state. Classification uses the HTTP status and Dropbox's structured error tag, exposed as `RequestError#code`.

| Signal | Error |
| --- | --- |
| HTTP 401 | `ReconnectRequired` |
| `invalid_grant`, `expired_access_token` | `ReconnectRequired` |
| Other failed Dropbox responses | `RecordingStudioDropbox::RequestError` (`status` and `code`, both may be nil) |

Do not rescue `StandardError` around these calls. Exception messages do not include the Dropbox response body.

## Install

Add the gem from GitHub. It is not published to RubyGems.

```ruby
gem "recording_studio_dropbox",
    github: "bowerbird-app/RecordingStudio_Dropbox",
    tag: "v0.3.0"

gem "recording_studio_oauth",
    github: "bowerbird-app/RecordingStudio_Oauth",
    tag: "v0.15.1"

gem "recording_studio_attachable",
    github: "bowerbird-app/RecordingStudio_attachable",
    tag: "v0.21.0"
```

```bash
bundle install
bin/rails generate recording_studio_oauth:install
bin/rails generate recording_studio_oauth:migrations
bin/rails generate recording_studio_attachable:install
bin/rails generate recording_studio_attachable:migrations
bin/rails generate recording_studio_dropbox:install
bin/rails db:migrate
```

Mount Oauth and Attachable:

```ruby
mount RecordingStudioOauth::Engine, at: "/recording_studio_oauth"
mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"
```

The dummy app at `test/dummy` is a host that boots the engine. Sign in at `/users/sign_in` with `admin@admin.com` / `Password`. Dummy uses a fake Dropbox provider so tests run without real Dropbox credentials.

Boot the dummy from `test/dummy`:

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Optional dummy env vars for a live Dropbox app: `DROPBOX_CLIENT_ID`, `DROPBOX_CLIENT_SECRET`, and `RAILS_DEVELOPMENT_HOSTS`. Dummy also reads `attachable.dropbox` or `dropbox` from Rails credentials when those files exist. The upload page for the seeded Studio Workspace is `/recording_studio_attachable/recordings/<workspace-root-id>/attachments/upload`. Seeds print that path.

## Version

0.3.0
