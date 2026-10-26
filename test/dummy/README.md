# Dummy App

This Rails app exists to validate the Recording Studio Dropbox gem in a real host application.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables
- Recording Studio default layout, FlatPack assets, and Tailwind source scanning
- Mounted `RecordingStudio::Engine` route behavior inside a host app
- Dropbox connect, disconnect, and reconnect through Recording Studio Oauth, using a fake Dropbox provider (no real credentials)
- Attachable upload page with Dropbox Chooser and the file-list import page
- Dummy-only `/docs/*` pages for gem-specific onboarding

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

For a live Dropbox app in development, set
`credentials.recording_studio_oauth.outbound.dropbox.client_id` and
`client_secret`. Set Chooser `RecordingStudioDropbox.configuration.client_id` in
`config/initializers/recording_studio_dropbox.rb`. Set `RAILS_DEVELOPMENT_HOSTS`
if the host is not localhost.

## Useful Routes

- `/` - dummy app home page for Dropbox connect, disconnect, and reconnect
- `/recording_studio_attachable/recordings/<workspace-root-id>/attachments/upload` - Attachable upload page (Chooser and Dropbox file list). Seeds print the seeded workspace URL.
- `/recording_studio_attachable/dropbox/recordings/<workspace-root-id>/imports` - Dropbox file-list import page
- `/recording_studio_oauth` - Oauth engine (outbound callback lives here)
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Devise sign-in page
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - dummy-only starter pages
- `/up` - Rails health check

## Why This App Exists

Use this app to verify that the Dropbox client boots inside a Recording Studio host. If a layout, route, asset source, or Recording Studio initializer change breaks here, fix it before a host app copies the pattern.

Authenticated pages use Recording Studio's shared default layout. Devise sign-in keeps `layouts/application`.

The home page in `app/views/home/index.html.erb` should stay a minimal demo surface for Dropbox connect. Do not turn it into a wall of documentation; the dummy docs pages exist so deeper explanations can live in focused sections.
