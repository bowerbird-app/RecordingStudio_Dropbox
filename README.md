# Recording Studio Dropbox

This gem talks to the Dropbox HTTP API for Recording Studio. It lists folders, fetches metadata, downloads files, and uploads files. Files are copied into storage later. This gem does not link Dropbox files in place.

It does not register an Attachable upload source in this release. That work is a later phase.

## What you get

`RecordingStudioDropbox::Client` is the public entry. Pass an access token through `RecordingStudioDropbox::AccessToken`. The client does not load RecordingStudioOauth yet.

| Method | Dropbox endpoints |
| --- | --- |
| `list_folder` | `/2/files/list_folder` and `/2/files/list_folder/continue` |
| `search` | `/2/files/search_v2` and `/2/files/search/continue_v2` |
| `metadata` | `/2/files/get_metadata` |
| `download` | `/2/files/download` |
| `upload` | `/2/files/upload`, or a session (`start`, `append_v2`, `finish`) when the body is larger than 8 MiB |

`list_folder` and `search` return a `Page` with `entries`, `next_cursor` (nil when there are no more pages), and `more?`. Pass `cursor:` to fetch the next page. Download returns a `DownloadedFile` with `body`, `filename`, and `content_type`.

HTTP uses `Net::HTTP`, the same client Recording Studio Attachable uses for Dropbox today. There is no Dropbox SDK.

Scopes this client needs are `files.metadata.read`, `files.content.read`, and `files.content.write`.

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
client.list_folder(path: "")
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

The dummy app at `test/dummy` is a host that boots the engine. Sign in at `/users/sign_in` with `admin@admin.com` / `Password`. Dummy credentials use the shared Recording Studio development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key`. Do not mint a new master key.

## Version

0.1.0
