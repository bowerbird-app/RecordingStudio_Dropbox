# frozen_string_literal: true

require_relative "lib/recording_studio_dropbox/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_dropbox"
  spec.version     = RecordingStudioDropbox::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_Dropbox"
  spec.summary     = "Dropbox API client and Attachable upload add-on for Recording Studio"
  spec.description = "Lists, downloads, and uploads Dropbox files for Recording Studio. " \
                     "Tokens come from RecordingStudioOauth.connection_for on a Dropbox " \
                     "outbound provider registered by this gem. When RecordingStudioAttachable " \
                     "is loaded, this gem registers the Dropbox upload provider."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_Dropbox"
  spec.metadata["changelog_uri"] =
    "https://github.com/bowerbird-app/RecordingStudio_Dropbox/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "recording_studio_oauth", ">= 0.17.0", "< 1.0"
end
