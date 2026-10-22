# frozen_string_literal: true

module RecordingStudioDropbox
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioDropbox

    initializer "recording_studio_dropbox.before_initialize", before: "recording_studio_dropbox.load_config" do |_app|
      RecordingStudioDropbox.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_dropbox.load_config" do |app|
      if app.respond_to?(:config_for)
        yaml = begin
          app.config_for(:recording_studio_dropbox)
        rescue Errno::ENOENT, RuntimeError
          nil
        end
        RecordingStudioDropbox.configuration.merge!(yaml) if yaml.respond_to?(:each)
      end

      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_dropbox)
        xcfg = app.config.x.recording_studio_dropbox
        if xcfg.respond_to?(:to_h)
          RecordingStudioDropbox.configuration.merge!(xcfg.to_h)
        elsif xcfg.respond_to?(:each_pair)
          hash = {}
          xcfg.each_pair { |k, v| hash[k] = v }
          RecordingStudioDropbox.configuration.merge!(hash) if hash.any?
        end
      end

      RecordingStudioDropbox.configuration.hooks.run(:on_configuration, RecordingStudioDropbox.configuration)
    end

    initializer "recording_studio_dropbox.after_initialize", after: "recording_studio_dropbox.load_config" do |_app|
      RecordingStudioDropbox.configuration.hooks.run(:after_initialize, self)
    end
  end
end
