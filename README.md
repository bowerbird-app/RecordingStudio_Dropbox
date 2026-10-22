# Recording Studio Dropbox

This gem talks to the Dropbox HTTP API for Recording Studio. It lists folders, fetches metadata, downloads files, and uploads files. Files are copied into storage later. This gem does not link Dropbox files in place.

It does not register an Attachable upload source in this release. That work is a later phase.

## What you get

`RecordingStudioDropbox::Client` is the public entry. Pass an access token through `RecordingStudioDropbox::AccessToken`. The client does not load RecordingStudioOauth yet.

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

## Access token

`RecordingStudioDropbox::AccessToken.new(provider)` reads the token with `#to_s`. If the provider responds to `call`, that is used first. Otherwise it uses `#access_token`. A raw String is a misconfiguration and raises `ArgumentError`. A blank or nil token at request time raises `ReconnectRequired`.

```ruby
client = RecordingStudioDropbox::Client.new(
  token_provider: -> { "sl.access-token" }
)
```

An object that implements `access_token` also works:

```ruby
client = RecordingStudioDropbox::Client.new(token_provider: connection)
client.list(path: "")
```

Tests pass a callable provider and stub `Net::HTTP`.

`RecordingStudioDropbox.configure` yields the configuration and returns it.

## Errors

Token problems raise `RecordingStudioDropbox::ReconnectRequired`. Callers can turn that into a reconnect state. Classification uses the HTTP status and Dropbox's structured error tag, exposed as `RequestError#code`.

| Signal | Error |
| --- | --- |
| HTTP 401 | `ReconnectRequired` |
| `invalid_grant`, `expired_access_token` | `ReconnectRequired` |
| Other failed Dropbox responses | `RecordingStudioDropbox::RequestError` (`status` and `code`, both may be nil) |

Do not rescue `StandardError` around these calls. Exception messages do not include the Dropbox response body.

## Planned Oauth wiring

[RecordingStudioOauth](https://github.com/bowerbird-app/RecordingStudio_Oauth) will store encrypted Dropbox tokens and expose `connection_for(provider:, root:, actor:)`. That work is still in [pull request 62](https://github.com/bowerbird-app/RecordingStudio_Oauth/pull/62) and is not a dependency of this gem.

When it ships, wire the client like this:

```ruby
connection = RecordingStudioOauth.connection_for(
  provider: :dropbox,
  root: root_recording,
  actor: current_user
)
raise RecordingStudioDropbox::ReconnectRequired if connection.nil?

client = RecordingStudioDropbox::Client.new(
  token_provider: -> { connection.access_token }
)
```

Oauth lookup returns `nil` when a refresh fails and the row needs reconnect. Map that `nil` to `ReconnectRequired` in the caller.

## Planned Attachable wiring

A later phase will register this gem with RecordingStudioAttachable through `register_upload_provider`. Do not add that registration here.

## Install

Add the gem from GitHub. It is not published to RubyGems.

```ruby
gem "recording_studio_dropbox",
    github: "bowerbird-app/RecordingStudio_Dropbox",
    tag: "v0.1.0"
```

```bash
bundle install
bin/rails generate recording_studio_dropbox:install
```

The dummy app at `test/dummy` is a host that boots the engine. Sign in at `/users/sign_in` with `admin@admin.com` / `Password`.

## Version

0.1.0
