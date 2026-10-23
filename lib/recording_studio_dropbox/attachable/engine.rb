# frozen_string_literal: true

module RecordingStudioDropbox
  module Attachable
    class Engine < ::Rails::Engine
      isolate_namespace RecordingStudioDropbox::Attachable
      engine_name "recording_studio_dropbox_attachable"

      initializer "recording_studio_dropbox.attachable.register_upload_provider" do |app|
        app.config.to_prepare do
          RecordingStudioDropbox::Attachable::Integration.sync_upload_provider!
        end
      end
    end
  end
end

RecordingStudioDropbox::Attachable::Engine.routes.draw do
  resources :recordings, only: [] do
    get "bootstrap", to: "bootstrap#show", as: :bootstrap
    get "connect", to: "connect#show", as: :connect
    get "connected", to: "connect#complete", as: :connected
    delete "connect", to: "connect#destroy", as: :disconnect
    resources :imports, only: %i[index create], controller: "imports"
  end
end
