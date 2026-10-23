# frozen_string_literal: true

module RecordingStudioDropbox
  module Attachable
    class ConnectController < ApplicationController
      def show
        authorize_provider_upload!
        ensure_provider_available!
        @oauth_connect_path = oauth_connect_path
        @oauth_return_to = oauth_return_to(popup: params[:popup].to_s == "1")
        @reconnect = dropbox_reconnect?
        render :show
      rescue RecordingStudioAttachable::DependencyUnavailableError => e
        dependency_unavailable_alert(e)
      end

      def complete
        authorize_provider_upload!
        ensure_provider_available!
        render_provider_auth_complete(reload_url: connect_reload_url)
      rescue RecordingStudioAttachable::DependencyUnavailableError => e
        dependency_unavailable_alert(e)
      end

      def destroy
        authorize_provider_upload!
        ensure_provider_available!
        redirect_after_disconnect
      rescue RecordingStudioAttachable::DependencyUnavailableError => e
        dependency_unavailable_alert(e)
      end

      private

      def redirect_after_disconnect
        path = Integration.oauth_disconnect_path(
          Integration.connection_id_for(root: dropbox_root, actor: current_attachable_actor),
          return_to: recording_imports_path(@recording, **upload_flow_params)
        )
        if path.present?
          redirect_to path, status: :temporary_redirect
        else
          redirect_to recording_imports_path(@recording, **upload_flow_params),
                      alert: RecordingStudioAttachable::Copy.t(
                        "providers.disconnect_failed",
                        provider: provider_label,
                        default: "#{provider_label} isn't connected."
                      )
        end
      end
    end
  end
end
