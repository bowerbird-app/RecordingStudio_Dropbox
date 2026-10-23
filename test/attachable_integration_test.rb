# frozen_string_literal: true

require "test_helper"
require "recording_studio_dropbox/attachable/integration"
require "recording_studio_dropbox/attachable/import"

class AttachableIntegrationTest < Minitest::Test
  def test_reconnect_required_maps_dropbox_and_attachable_errors
    dropbox_error = RecordingStudioDropbox::ReconnectRequired.new("reconnect")
    other = RecordingStudioDropbox::RequestError.new("nope", status: 500)

    assert RecordingStudioDropbox::Attachable::Integration.reconnect_required?(dropbox_error)
    refute RecordingStudioDropbox::Attachable::Integration.reconnect_required?(other)
    assert RecordingStudioDropbox::Attachable::Integration.request_error?(other)
    refute RecordingStudioDropbox::Attachable::Integration.request_error?(dropbox_error)
  end

  def test_root_for_uses_the_recording_root_when_present
    root = Object.new
    child = Object.new
    child.define_singleton_method(:root_recording) { root }

    assert_equal root, RecordingStudioDropbox::Attachable::Integration.root_for(child)
    assert_equal root, RecordingStudioDropbox::Attachable::Integration.root_for(root)
  end

  def test_selection_from_reads_ids_from_strings_and_provider_payloads
    from_string = RecordingStudioDropbox::Attachable::Import.selection_from("id:file-1")
    from_hash = RecordingStudioDropbox::Attachable::Import.selection_from(
      { "provider_payload" => { "id" => "id:file-2", "name" => "Brief.pdf" }, "name" => "Brief.pdf" }
    )
    blank = RecordingStudioDropbox::Attachable::Import.selection_from({})

    assert_equal "id:file-1", from_string.fetch("id")
    assert_equal "id:file-2", from_hash.fetch("id")
    assert_equal "Brief.pdf", from_hash.fetch("name")
    assert_nil blank
  end

  def test_selections_from_drops_duplicates
    selections = RecordingStudioDropbox::Attachable::Import.selections_from(
      ["id:file-1", { "id" => "id:file-1" }, "id:file-2"]
    )

    ids = selections.map { |row| row.fetch("id") }
    assert_equal %w[id:file-1 id:file-2], ids
  end

  def test_remote_importer_is_keyword_only_and_accepts_context
    error = assert_raises(ArgumentError) do
      RecordingStudioDropbox::Attachable::Registration.remote_importer(
        Object.new, [], nil, nil
      )
    end
    assert_match(/missing keywords/, error.message)

    result = RecordingStudioDropbox::Attachable::Registration.remote_importer(
      parent_recording: Object.new,
      attachments: [],
      context: Object.new
    )
    refute result.success?
    assert_includes result.error, "Select at least one"
  end
end
