# frozen_string_literal: true

require "marcel"
require "stringio"

module RecordingStudioDropbox
  module Attachable
    module Import
      module_function

      def remote_files(parent_recording:, attachments:, actor: nil, impersonator: nil)
        selections = selections_from(attachments)
        return empty_selection_result if selections.blank?

        RecordingStudioAttachable::Services::ImportRemoteFiles.call(
          parent_recording: parent_recording,
          provider_key: Integration::PROVIDER_KEY,
          actor: actor,
          impersonator: impersonator,
          payloads: selections.map { |selection| payload_for(parent_recording, actor, selection) }
        )
      end

      def empty_selection_result
        RecordingStudioAttachable::Services::BaseService::Result.new(
          success: false,
          error: RecordingStudioAttachable::Copy.t(
            "providers.select_at_least_one",
            default: "Select at least one file"
          )
        )
      end

      def selections_from(attachments)
        Array(attachments).filter_map { |item| selection_from(item) }.uniq { |row| row.fetch("id") }
      end

      def selection_from(item)
        return string_selection(item) if item.is_a?(String)

        hash = stringify_hash(item)
        return if hash.blank?

        payload = stringify_hash(hash["provider_payload"]) || hash
        build_selection(hash, payload)
      end

      def stringify_hash(value)
        return unless value.respond_to?(:to_h)

        hash = value.to_h
        hash = hash.to_unsafe_h if hash.respond_to?(:to_unsafe_h)
        hash.deep_stringify_keys
      end

      def build_selection(hash, payload)
        id = payload["id"]
        return if id.blank?

        {
          "id" => id.to_s,
          "name" => (hash["name"].presence || payload["name"]).presence,
          "description" => hash["description"].presence
        }.compact
      end

      def string_selection(item)
        item.presence && { "id" => item }
      end

      def payload_for(parent_recording, actor, selection)
        path = selection.fetch("id")
        {
          filename: selection["name"],
          name: selection["name"],
          description: selection["description"].presence || "Imported from Dropbox",
          download: -> { download_file(parent_recording, actor, path) },
          metadata: { external_id: path }
        }.compact
      end

      def download_file(parent_recording, actor, path)
        client = Integration.client(root: Integration.root_for(parent_recording), actor: actor)
        metadata = client.fetch_file(path: path)
        downloaded = client.download(path: path)
        filename = downloaded.filename.presence || metadata.name
        {
          io: StringIO.new(downloaded.body),
          filename: filename,
          content_type: downloaded.content_type.presence || Marcel::MimeType.for(name: filename),
          byte_size: metadata.size
        }
      end
    end
  end
end
