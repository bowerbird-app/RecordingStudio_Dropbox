# frozen_string_literal: true

module RecordingStudioDropbox
  module Attachable
    module Registration
      PROVIDER_KEY = :dropbox
      PROVIDER_LABEL = "Dropbox"
      LAUNCHER = "dropbox"
      LAUNCHER_MODULE = "recording_studio_dropbox/dropbox_picker_launcher"

      module_function

      def provider_options
        paths.merge(identity).merge(hooks)
      end

      def identity
        {
          label: PROVIDER_LABEL,
          icon: "cloud",
          strategy: :client_picker,
          launcher: LAUNCHER,
          launcher_module: LAUNCHER_MODULE,
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
        helpers = dropbox_helpers(context)
        return if helpers.blank?

        {
          url: Oauth.oauth_connect_path,
          method: "post",
          fields: connect_fields(recording, context, helpers),
          fallback_url: helpers.recording_connect_path(recording, popup: 1)
        }.compact
      end

      def connect_fields(recording, context, helpers)
        token = context.provider_csrf_token if context.respond_to?(:provider_csrf_token)
        {
          authenticity_token: token,
          owner: "root",
          root_recording_id: root_for(recording)&.id,
          return_to: helpers.recording_connected_path(recording, popup: 1)
        }.compact
      end

      def reconnect_required?(error)
        error.is_a?(RecordingStudioDropbox::ReconnectRequired) || attachable_reconnect?(error)
      end

      def attachable_reconnect?(error)
        defined?(RecordingStudioAttachable::ReconnectRequired) &&
          error.is_a?(RecordingStudioAttachable::ReconnectRequired)
      end

      def request_error?(error)
        error.is_a?(RecordingStudioDropbox::RequestError)
      end

      def client(root:, actor:)
        token = RecordingStudioDropbox::OauthToken.new(root: root, actor: actor)
        RecordingStudioDropbox::Client.new(token_provider: token)
      end

      def chooser_access(root:, actor:)
        status = Oauth.connection_status(root: root, actor: actor)
        connected = status == :active && Oauth.connection(root: root, actor: actor).present?
        return if connected

        raise RecordingStudioDropbox::ReconnectRequired, "Dropbox reconnect required"
      end

      def dropbox_helpers(context)
        return context.dropbox if context.respond_to?(:dropbox)
        return context if context.respond_to?(:recording_connect_path)

        nil
      end

      def root_for(recording)
        return recording unless recording.respond_to?(:root_recording)

        recording.root_recording || recording
      end
    end
  end
end
