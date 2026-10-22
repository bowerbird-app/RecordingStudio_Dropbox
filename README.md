# Recording Studio Dropbox

This gem talks to the Dropbox HTTP API for Recording Studio. It lists folders, fetches metadata, downloads files, and uploads files. Files are copied into storage later. This gem does not link Dropbox files in place.

Dropbox uses user OAuth. Tokens live on RecordingStudioOauth outbound connections. This gem does not register an Attachable upload source in this release. That work is a later phase.

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

Scopes this client needs are `files.metadata.read`, `files.content.read`, and `files.content.write`.

## Shared shape with Google Drive

This client uses the same method names as RecordingStudio Google Drive: `list`, `search`, `fetch_file`, `download`, and `upload_file`. Locators stay provider-native. Dropbox takes `path:` (a Dropbox path, or an `id:`, `ns:`, or `rev:` prefix). Google Drive takes Drive ids (`parent_id`, `file_id`). `search` is the same on both gems: query plus cursor paging, not a folder locator. `upload_file` takes `io:` on both. Google Drive also requires `content_type:`; Dropbox omits it because the Dropbox upload API does not use it.

## Oauth tokens

Register the Dropbox provider from this gem, not from Oauth:

```ruby
RecordingStudioDropbox.register_oauth_provider
```

That call uses Oauth's public registry. Authorize and token URLs are Dropbox's. Refresh is on. `token_access_type` is `offline`.

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

`RecordingStudioDropbox.configure` yields the configuration and returns it.

## Errors

Token problems raise `RecordingStudioDropbox::ReconnectRequired`. Callers can turn that into a reconnect state. Classification uses the HTTP status and Dropbox's structured error tag, exposed as `RequestError#code`.

| Signal | Error |
| --- | --- |
| HTTP 401 | `ReconnectRequired` |
| `invalid_grant`, `expired_access_token` | `ReconnectRequired` |
| Other failed Dropbox responses | `RecordingStudioDropbox::RequestError` (`status` and `code`, both may be nil) |

Do not rescue `StandardError` around these calls. Exception messages do not include the Dropbox response body.

## Planned Attachable wiring

A later phase will register this gem with RecordingStudioAttachable through `register_upload_provider`. Do not add that registration here.

## Install

Add the gem from GitHub. It is not published to RubyGems.

```ruby
gem "recording_studio_dropbox",
    github: "bowerbird-app/RecordingStudio_Dropbox",
    tag: "v0.2.0"

gem "recording_studio_oauth",
    github: "bowerbird-app/RecordingStudio_Oauth",
    tag: "v0.14.1"
```

```bash
bundle install
bin/rails generate recording_studio_oauth:install
bin/rails generate recording_studio_oauth:migrations
bin/rails generate recording_studio_dropbox:install
bin/rails db:migrate
```

Mount Oauth so people can connect, disconnect, and reconnect:

```ruby
mount RecordingStudioOauth::Engine, at: "/recording_studio_oauth"
```

The dummy app at `test/dummy` is a host that boots the engine. Sign in at `/users/sign_in` with `admin@admin.com` / `Password`. Dummy uses a fake Dropbox provider so it runs without real Dropbox credentials.

## Version

0.2.0
