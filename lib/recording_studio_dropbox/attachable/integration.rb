# frozen_string_literal: true

module RecordingStudioDropbox
  module Attachable
    module Integration
      PROVIDER_KEY = :dropbox
      PROVIDER_LABEL = "Dropbox"
      LAUNCHER = "dropbox"
      LAUNCHER_MODULE = "recording_studio_dropbox/dropbox_picker_launcher"

      module_function

      def sync_upload_provider!
        return unless defined?(RecordingStudioAttachable)

        if RecordingStudioDropbox.configuration.available?
          RecordingStudioAttachable.register_upload_provider(PROVIDER_KEY, **provider_options)
        else
          clear_upload_provider!
        end
      end

      def clear_upload_provider!
        config = RecordingStudioAttachable.configuration
        config.upload_providers = config.upload_providers.reject { |provider| provider.key == PROVIDER_KEY }
      end

      def provider_options
        {
          label: PROVIDER_LABEL,
          icon: "cloud",
          strategy: :client_picker,
          launcher: LAUNCHER,
          launcher_module: LAUNCHER_MODULE,
          allowed_payload_keys: %w[id],
          url: method(:bootstrap_path),
          bootstrap_url: method(:bootstrap_path),
          import_url: method(:import_path),
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

      def remote_importer(parent_recording:, attachments:, actor: nil, impersonator: nil, **)
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
          url: oauth_connect_path,
          method: "post",
          fields: {
            authenticity_token: (context.provider_csrf_token if context.respond_to?(:provider_csrf_token)),
            owner: "user",
            return_to: helpers.recording_connected_path(recording, popup: 1)
          }.compact,
          fallback_url: helpers.recording_connect_path(recording, popup: 1)
        }.compact
      end

      def reconnect_required?(error)
        error.is_a?(RecordingStudioDropbox::ReconnectRequired) ||
          (defined?(RecordingStudioAttachable::ReconnectRequired) &&
            error.is_a?(RecordingStudioAttachable::ReconnectRequired))
      end

      def request_error?(error)
        error.is_a?(RecordingStudioDropbox::RequestError)
      end

      def client(root:, actor:)
        RecordingStudioDropbox::Client.new(
          token_provider: RecordingStudioDropbox::OauthToken.new(root: root, actor: actor)
        )
      end

      def chooser_access(root:, actor:)
        RecordingStudioDropbox::OauthToken.new(root: root, actor: actor).call
      end

      def connection(root:, actor:)
        return unless defined?(::RecordingStudioOauth)

        ::RecordingStudioOauth.connection_for(provider: PROVIDER_KEY, root: root, actor: actor)
      end

      def connection_status(root:, actor:)
        return :missing unless defined?(::RecordingStudioOauth)

        ::RecordingStudioOauth.connection_status(provider: PROVIDER_KEY, root: root, actor: actor)
      end

      def connection_id_for(root:, actor:)
        return unless defined?(::RecordingStudioOauth)

        ::RecordingStudioOauth.connection_id_for(provider: PROVIDER_KEY, root: root, actor: actor)
      end

      def oauth_connect_path
        return unless defined?(::RecordingStudioOauth)

        ::RecordingStudioOauth::Engine.routes.url_helpers.outbound_connect_path(provider: PROVIDER_KEY)
      end

      def oauth_disconnect_path(connection_id, return_to:)
        return if connection_id.blank? || !defined?(::RecordingStudioOauth)

        ::RecordingStudioOauth::Engine.routes.url_helpers.outbound_connection_path(
          connection_id,
          return_to: return_to
        )
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
