# frozen_string_literal: true

module RecordingStudioDropbox
  module Attachable
    class BootstrapController < ApplicationController
      def show
        authorize_provider_upload!
        ensure_provider_available!
        ensure_chooser_configured!

        render json: bootstrap_payload
      rescue RecordingStudioAttachable::DependencyUnavailableError => e
        render json: { error: e.message }, status: :unprocessable_content
      end

      private

      def bootstrap_payload
        needs_auth, reconnect = auth_flags
        payload = provider_connect_payload(
          needs_auth: needs_auth,
          reconnect: reconnect,
          import_url: recording_imports_path(@recording, format: :json, **attachment_redirect_params)
        )
        payload = payload.except(:connect) unless payload[:needs_auth]
        payload.merge(client_id: dropbox_configuration.client_id)
      end

      def auth_flags
        Integration.chooser_access(root: dropbox_root, actor: current_attachable_actor)
        [false, false]
      rescue RecordingStudioDropbox::ReconnectRequired, RecordingStudioAttachable::ReconnectRequired
        [true, true]
      end
    end
  end
end
