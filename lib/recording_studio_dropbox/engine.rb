# frozen_string_literal: true

module RecordingStudioDropbox
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioDropbox

    initializer "recording_studio_dropbox.before_initialize", before: "recording_studio_dropbox.load_config" do |_app|
      RecordingStudioDropbox.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_dropbox.load_config" do |_app|
      RecordingStudioDropbox.configuration.hooks.run(:on_configuration, RecordingStudioDropbox.configuration)
    end

    initializer "recording_studio_dropbox.after_initialize", after: "recording_studio_dropbox.load_config" do |_app|
      RecordingStudioDropbox.configuration.hooks.run(:after_initialize, self)
    end

    initializer "recording_studio_dropbox.assets" do |app|
      next unless app.config.respond_to?(:assets)

      app.config.assets.paths << root.join("app/javascript")
    end
  end
end

ActiveSupport.on_load(:recording_studio_attachable) do
  attached = Gem::Version.new(RecordingStudioAttachable::VERSION)
  required = Gem::Version.new("0.21.0")
  if attached < required
    raise "RecordingStudioDropbox's Attachable add-on needs " \
          "recording_studio_attachable 0.21.0 or newer " \
          "(got #{RecordingStudioAttachable::VERSION})."
  end

  require "recording_studio_dropbox/attachable"
end
