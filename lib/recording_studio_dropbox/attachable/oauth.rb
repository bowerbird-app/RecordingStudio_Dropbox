# frozen_string_literal: true

module RecordingStudioDropbox
  module Attachable
    module Oauth
      module_function

      def connection(root:, actor:)
        return unless defined?(::RecordingStudioOauth)

        ::RecordingStudioOauth.connection_for(provider: Registration::PROVIDER_KEY, root: root, actor: actor)
      end

      def connection_status(root:, actor:)
        return unless defined?(::RecordingStudioOauth)
        return oauth_connection_status(root, actor) if ::RecordingStudioOauth.respond_to?(:connection_status)

        connection(root: root, actor: actor) ? :connected : :missing
      end

      def connection_id_for(root:, actor:)
        return unless defined?(::RecordingStudioOauth)
        return oauth_connection_id(root, actor) if ::RecordingStudioOauth.respond_to?(:connection_id_for)

        connection(root: root, actor: actor)&.id
      end

      def oauth_connection_status(root, actor)
        ::RecordingStudioOauth.connection_status(provider: Registration::PROVIDER_KEY, root: root, actor: actor)
      end

      def oauth_connection_id(root, actor)
        ::RecordingStudioOauth.connection_id_for(provider: Registration::PROVIDER_KEY, root: root, actor: actor)
      end

      def oauth_connect_path
        return unless defined?(::RecordingStudioOauth)

        ::RecordingStudioOauth::Engine.routes.url_helpers.outbound_connect_path(
          provider: Registration::PROVIDER_KEY
        )
      end

      def oauth_disconnect_path(connection_id, return_to:)
        return if connection_id.blank? || !defined?(::RecordingStudioOauth)

        ::RecordingStudioOauth::Engine.routes.url_helpers.outbound_connection_path(
          connection_id,
          return_to: return_to
        )
      end
    end
  end
end
