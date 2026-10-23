# frozen_string_literal: true

require "recording_studio_dropbox/attachable/oauth"
require "recording_studio_dropbox/attachable/registration"

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
        remaining = config.upload_providers.reject { |provider| provider.key == PROVIDER_KEY }
        config.upload_providers = remaining
      end

      def provider_options(...) = Registration.provider_options(...)
      def bootstrap_path(...) = Registration.bootstrap_path(...)
      def import_path(...) = Registration.import_path(...)
      def remote_importer(...) = Registration.remote_importer(...)
      def connect_payload(...) = Registration.connect_payload(...)

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
        RecordingStudioDropbox::OauthToken.new(root: root, actor: actor).call
      end

      def connection(...) = Oauth.connection(...)
      def connection_status(...) = Oauth.connection_status(...)
      def connection_id_for(...) = Oauth.connection_id_for(...)
      def oauth_connect_path(...) = Oauth.oauth_connect_path(...)
      def oauth_disconnect_path(...) = Oauth.oauth_disconnect_path(...)

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
