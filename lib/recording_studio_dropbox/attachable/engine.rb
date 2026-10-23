# frozen_string_literal: true

module RecordingStudioDropbox
  module Attachable
    class Engine < ::Rails::Engine
      isolate_namespace RecordingStudioDropbox::Attachable
      engine_name "recording_studio_dropbox_attachable"

      paths["config/routes.rb"] << "config/recording_studio_dropbox_attachable_routes.rb"

      initializer "recording_studio_dropbox.attachable.register_upload_provider" do |app|
        app.config.to_prepare do
          next unless defined?(RecordingStudioAttachable)
          next unless RecordingStudioDropbox.configuration.available?

          RecordingStudioAttachable.register_upload_provider(
            RecordingStudioDropbox::Attachable::Registration::PROVIDER_KEY,
            **RecordingStudioDropbox::Attachable::Registration.provider_options
          )
        end
      end
    end
  end
end
