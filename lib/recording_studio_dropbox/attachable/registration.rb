# frozen_string_literal: true

module RecordingStudioDropbox
  module Attachable
    module Registration
      module_function

      def provider_options
        paths.merge(identity).merge(hooks)
      end

      def identity
        {
          label: Integration::PROVIDER_LABEL,
          icon: "cloud",
          strategy: :client_picker,
          launcher: Integration::LAUNCHER,
          launcher_module: Integration::LAUNCHER_MODULE,
          allowed_payload_keys: %w[id]
        }
      end

      def paths
        {
          url: method(:bootstrap_path),
          bootstrap_url: method(:bootstrap_path),
          import_url: method(:import_path)
        }
      end

      def hooks
        {
          remote_importer: method(:remote_importer),
          connect: method(:connect_payload),
          reconnect_error: method(:reconnect_required?)
        }
      end

      def bootstrap_path(route_helpers:, recording:)
        route_helpers.dropbox.recording_bootstrap_path(recording, format: :json)
      end

      def import_path(route_helpers:, recording:)
        route_helpers.dropbox.recording_imports_path(recording, format: :json)
      end

      def remote_importer(parent_recording:, attachments:, actor: nil, impersonator: nil, context: nil)
        _ = context
        Import.remote_files(
          parent_recording: parent_recording,
          attachments: attachments,
          actor: actor,
          impersonator: impersonator
        )
      end

      def connect_payload(recording:, context:)
        helpers = Integration.dropbox_helpers(context)
        return if helpers.blank?

        {
          url: Integration.oauth_connect_path,
          method: "post",
          fields: connect_fields(recording, context, helpers),
          fallback_url: helpers.recording_connect_path(recording, popup: 1)
        }.compact
      end

      def connect_fields(recording, context, helpers)
        token = context.provider_csrf_token if context.respond_to?(:provider_csrf_token)
        {
          authenticity_token: token,
          owner: "user",
          return_to: helpers.recording_connected_path(recording, popup: 1)
        }.compact
      end

      def reconnect_required?(error)
        Integration.reconnect_required?(error)
      end
    end
  end
end
