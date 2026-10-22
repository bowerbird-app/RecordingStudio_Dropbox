# Recording Studio Dropbox

This gem talks to the Dropbox HTTP API for Recording Studio. It lists folders, fetches metadata, downloads files, and uploads files. Files are copied into storage later. This gem does not link Dropbox files in place.

It does not register an Attachable upload source in this release. That work is a later phase.

## What you get

`RecordingStudioDropbox::Client` is the public entry. Pass an access token through a token provider. The client does not load RecordingStudioOauth yet.

| Method | Dropbox endpoints |
| --- | --- |
| `list_folder` | `/2/files/list_folder` and `/2/files/list_folder/continue` |
| `search` | `/2/files/search_v2` and `/2/files/search/continue_v2` |
| `metadata` | `/2/files/get_metadata` |
| `download` | `/2/files/download` |
| `upload` | `/2/files/upload`, or a session (`start`, `append_v2`, `finish`) when the body is larger than 8 MiB |

HTTP uses `Net::HTTP`, the same client Recording Studio Attachable uses for Dropbox today. There is no Dropbox SDK.

Scopes this client needs are `files.metadata.read`, `files.content.read`, and `files.content.write`.

## Token provider

The client asks the provider for a fresh access token on each request.

A callable works:

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

Tests pass a fake provider and stub `Net::HTTP`.

A missing or blank token raises `RecordingStudioDropbox::ReconnectRequired`.

## Errors

Token problems raise `RecordingStudioDropbox::ReconnectRequired`. Callers can turn that into a reconnect state. Classification uses the HTTP status and Dropbox's structured `error[".tag"]` field.

| Signal | Error |
| --- | --- |
| HTTP 401 | `ReconnectRequired` |
| `expired_access_token`, `invalid_access_token`, `missing_scope` | `ReconnectRequired` |
| Other failed Dropbox responses | `RecordingStudioDropbox::ApiError` |

Do not rescue `StandardError` around these calls.

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
