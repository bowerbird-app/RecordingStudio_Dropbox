# frozen_string_literal: true

require "recording_studio"
require "recording_studio_dropbox/version"
require "recording_studio_dropbox/engine"
require "recording_studio_dropbox/configuration"
require "recording_studio_dropbox/errors"
require "recording_studio_dropbox/token_provider"
require "recording_studio_dropbox/entry"
require "recording_studio_dropbox/listing"
require "recording_studio_dropbox/downloaded_file"
require "recording_studio_dropbox/uploaded_file"
require "recording_studio_dropbox/transport"
require "recording_studio_dropbox/upload"
require "recording_studio_dropbox/client"

module RecordingStudioDropbox
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end
  end
end
