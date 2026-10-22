# frozen_string_literal: true

require "rails/generators"

module RecordingStudioDropbox
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs RecordingStudioDropbox into your application"

      def copy_initializer
        template "recording_studio_dropbox_initializer.rb", "config/initializers/recording_studio_dropbox.rb"
      end

      def add_yaml_config
        prompt = "Add config/recording_studio_dropbox.yml for environment-specific settings? [y/N]"
        return unless yes?(prompt)

        template "recording_studio_dropbox.yml", "config/recording_studio_dropbox.yml"
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end
    end
  end
end
