# frozen_string_literal: true

module RecordingStudioDropbox
  module Attachable
    class Engine < ::Rails::Engine
      isolate_namespace RecordingStudioDropbox::Attachable
      engine_name "recording_studio_dropbox_attachable"

      paths["config/routes.rb"] << "config/recording_studio_dropbox_attachable_routes.rb"

      initializer "recording_studio_dropbox.attachable.register_upload_provider" do |app|
        app.config.to_prepare do
          RecordingStudioDropbox::Attachable::Integration.sync_upload_provider!
        end
      end
    end
  end
end
