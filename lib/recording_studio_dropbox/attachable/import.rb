# frozen_string_literal: true

require "marcel"
require "stringio"
require "recording_studio_dropbox/attachable/import/selections"

module RecordingStudioDropbox
  module Attachable
    module Import
      SelectionResult = Struct.new(:error, :value, keyword_init: true) do
        def success?
          error.blank?
        end
      end

      module_function

      def remote_files(parent_recording:, attachments:, actor: nil, impersonator: nil)
        selections = selections_from(attachments)
        return empty_selection_result if selections.blank?

        import_remote_files(
          parent_recording: parent_recording,
          actor: actor,
          impersonator: impersonator,
          payloads: selections.map { |selection| payload_for(parent_recording, actor, selection) }
        )
      rescue ArgumentError => e
        SelectionResult.new(error: e.message)
      end

      def import_remote_files(parent_recording:, actor:, impersonator:, payloads:)
        RecordingStudioAttachable::Services::ImportRemoteFiles.call(
          parent_recording: parent_recording,
          provider_key: Registration::PROVIDER_KEY,
          actor: actor,
          impersonator: impersonator,
          payloads: payloads
        )
      end

      def selections_from(attachments) = Selections.selections_from(attachments)
      def selection_from(item) = Selections.selection_from(item)

      def empty_selection_result
        SelectionResult.new(
          error: I18n.t(
            "recording_studio_dropbox.select_at_least_one",
            default: "Select at least one file"
          )
        )
      end

      def payload_for(parent_recording, actor, selection)
        path = selection.fetch("id")
        client = Registration.client(root: Registration.root_for(parent_recording), actor: actor)
        metadata = client.fetch_file(path: path)
        filename = selection["name"].presence || metadata.name
        byte_size = metadata.size
        refuse_if_oversized!(byte_size)
        remote_payload(client, path, filename, byte_size, selection["description"])
      end

      def remote_payload(client, path, filename, byte_size, description)
        {
          filename: filename,
          name: filename,
          description: description.presence || imported_from_dropbox,
          byte_size: byte_size,
          download: -> { download_file(client, path, filename, byte_size) },
          metadata: { external_id: path }
        }.compact
      end

      def imported_from_dropbox
        I18n.t("recording_studio_dropbox.imported_from_dropbox", default: "Imported from Dropbox")
      end

      def download_file(client, path, filename, byte_size)
        refuse_if_oversized!(byte_size)
        max_bytes = Import.attachable_max_file_size
        downloaded = client.download(path: path, max_bytes: max_bytes)
        {
          io: StringIO.new(downloaded.body),
          filename: downloaded.filename.presence || filename,
          content_type: downloaded.content_type.presence || Marcel::MimeType.for(name: filename),
          byte_size: downloaded.body.bytesize
        }
      end

      def refuse_if_oversized!(byte_size)
        max_bytes = Import.attachable_max_file_size
        return if max_bytes.blank? || byte_size.blank?
        return if byte_size.to_i <= max_bytes

        raise ArgumentError, RecordingStudioDropbox.file_too_large_message
      end

      def attachable_max_file_size
        return unless defined?(RecordingStudioAttachable)

        RecordingStudioAttachable.configuration.max_file_size
      end
    end
  end
end
