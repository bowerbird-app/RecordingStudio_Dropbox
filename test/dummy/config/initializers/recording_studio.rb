# frozen_string_literal: true

RecordingStudio.configure do |config|
  # Registered delegated_type recordables (strings or classes)
  config.recordable_types = [
    "Workspace",
    "Folder",
    "Page",
    "RecordingStudioSiteSettings::SiteSetting",
    "RecordingStudioAttachable::Attachment",
    "RecordingStudio::Access",
    "RecordingStudioApi::ApiAccessToken",
    "RecordingStudioApi::ApiClient",
    "RecordingStudioApi::ApiCredential"
  ]

  # API declares AdminApi only when admin_root_recordable_type_names names a
  # loaded root. Register it in that same case. An empty list must not add it.
  Rails.application.config.to_prepare do
    next unless defined?(RecordingStudioApi)
    next if Array(RecordingStudioApi.configuration.admin_root_recordable_type_names).blank?

    types = RecordingStudio.configuration.recordable_types.map(&:to_s)
    next if types.include?("RecordingStudioApi::AdminApi")

    RecordingStudio.configuration.recordable_types = types + [ "RecordingStudioApi::AdminApi" ]
  end

  # Require each configured ActiveRecord type to call recording_studio_recordable.
  config.require_recordable_declarations = true

  # Recording Studio 7 denies a write when authorize_write is unset.
  # create_root_recording! calls this with root_recording nil. A present actor
  # may create that root and later recordings.
  config.authorize_write = ->(actor:, **) { actor.present? }

  # Shown in the shared default layout title fallback.
  config.app_name = "Dropbox Demo" if config.respond_to?(:app_name=)

  # Actor resolver for events when no actor is explicitly supplied
  config.actor = -> { Current.actor }

  # Emit ActiveSupport::Notifications events
  config.event_notifications_enabled = true

  # Idempotency behavior for log_event!
  config.idempotency_mode = :return_existing # or :raise

  # Recordable duplication strategy for revisions
  config.recordable_dup_strategy = :dup
end
