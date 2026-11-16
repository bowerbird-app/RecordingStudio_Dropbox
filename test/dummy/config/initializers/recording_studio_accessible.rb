# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [
    "User",
    "RecordingStudioApi::ApiClient",
    "RecordingStudioOauth::OauthAuthorization"
  ]

  # Accessible 0.45 allows mounted admin pages for an actor with an admin grant
  # on this kept root. The dummy staff root is Studio Workspace.
  config.admin_root_resolver = lambda do |**|
    workspace = Workspace.find_by(name: "Studio Workspace")
    next unless workspace

    RecordingStudio.root_recording_for(workspace)
  end
end
