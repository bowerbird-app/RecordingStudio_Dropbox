# frozen_string_literal: true

module RecordingStudioDropbox
  module Attachable
    class ApplicationController < RecordingStudioAttachable::ProviderController
      self.upload_provider_key = :dropbox

      private

      def dropbox_configuration
        RecordingStudioDropbox.configuration
      end

      def dropbox_root
        Integration.root_for(@recording || find_recording)
      end

      def dropbox_client
        Integration.client(root: dropbox_root, actor: current_attachable_actor)
      end

      def dropbox_connected?
        Integration.connection(root: dropbox_root, actor: current_attachable_actor).present?
      end

      def dropbox_reconnect?
        Integration.connection_status(root: dropbox_root, actor: current_attachable_actor) == :needs_reconnect
      end

      def oauth_connect_path
        Integration.oauth_connect_path
      end

      def oauth_return_to(popup:)
        if popup
          recording_connected_path(@recording, popup: 1, **upload_flow_params)
        else
          recording_imports_path(@recording, **upload_flow_params)
        end
      end

      def ensure_chooser_configured!
        return if dropbox_configuration.chooser_configured?

        raise RecordingStudioAttachable::DependencyUnavailableError,
              I18n.t(
                "recording_studio_dropbox.chooser_requires_config",
                default: "Dropbox Chooser needs an app key"
              )
      end

      def connect_reload_url
        recording_imports_path(
          @recording,
          **upload_flow_params,
          embed: "modal",
          provider_key: "dropbox"
        )
      end
    end
  end
end
