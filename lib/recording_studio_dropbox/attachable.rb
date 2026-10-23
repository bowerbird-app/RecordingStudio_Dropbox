# frozen_string_literal: true

require "recording_studio_dropbox/attachable/engine"
require "recording_studio_dropbox/attachable/integration"
require "recording_studio_dropbox/attachable/import"

module RecordingStudioDropbox
  module Attachable
  end
end

RecordingStudioAttachable.register_adapter_routes(:dropbox) do
  mount RecordingStudioDropbox::Attachable::Engine, at: "/dropbox", as: :dropbox
end
