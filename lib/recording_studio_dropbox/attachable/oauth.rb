# frozen_string_literal: true

module RecordingStudioDropbox
  module Attachable
    module Oauth
      module_function

      def connection(root:, actor:)
        return unless defined?(::RecordingStudioOauth)

        ::RecordingStudioOauth.connection_for(provider: Integration::PROVIDER_KEY, root: root, actor: actor)
      end

      def connection_status(root:, actor:)
        return :connected if connection(root: root, actor: actor)

        row = live_connection(actor: actor)
        return :missing if row.nil?
        return :needs_reconnect if row.needs_reconnect?

        :connected
      end

      def connection_id_for(root:, actor:)
        live_connection(actor: actor)&.id || connection(root: root, actor: actor)&.id
      end

      def live_connection(actor:)
        return unless defined?(::RecordingStudioOauth::OutboundConnection)

        ::RecordingStudioOauth::OutboundConnection.live.for_provider(Integration::PROVIDER_KEY).find_by(
          owner_actor: actor
        )
      end

      def oauth_connect_path
        return unless defined?(::RecordingStudioOauth)

        ::RecordingStudioOauth::Engine.routes.url_helpers.outbound_connect_path(
          provider: Integration::PROVIDER_KEY
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
