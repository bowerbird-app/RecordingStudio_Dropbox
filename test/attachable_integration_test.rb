# frozen_string_literal: true

require "test_helper"
require "recording_studio_dropbox/attachable/registration"
require "recording_studio_dropbox/attachable/import"
require "recording_studio_dropbox/attachable/oauth"

class AttachableIntegrationTest < Minitest::Test
  def test_reconnect_required_maps_dropbox_and_attachable_errors
    dropbox_error = RecordingStudioDropbox::ReconnectRequired.new("reconnect")
    other = RecordingStudioDropbox::RequestError.new("nope", status: 500)

    assert RecordingStudioDropbox::Attachable::Registration.reconnect_required?(dropbox_error)
    refute RecordingStudioDropbox::Attachable::Registration.reconnect_required?(other)
    assert RecordingStudioDropbox::Attachable::Registration.request_error?(other)
    refute RecordingStudioDropbox::Attachable::Registration.request_error?(dropbox_error)
  end

  def test_root_for_uses_the_recording_root_when_present
    root = Object.new
    child = Object.new
    child.define_singleton_method(:root_recording) { root }

    assert_equal root, RecordingStudioDropbox::Attachable::Registration.root_for(child)
    assert_equal root, RecordingStudioDropbox::Attachable::Registration.root_for(root)
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
    assert_match(/required keywords: parent_recording, attachments/, error.message)

    result = RecordingStudioDropbox::Attachable::Registration.remote_importer(
      parent_recording: Object.new,
      attachments: [],
      context: Object.new
    )
    refute result.success?
    assert_includes result.error, "Select at least one"
  end

  def test_import_refuses_oversized_metadata_before_download
    downloaded = false
    client = Object.new
    client.define_singleton_method(:fetch_file) do |**|
      RecordingStudioDropbox::Entry.new(
        id: "id:file-1",
        name: "Huge.pdf",
        path: "/Huge.pdf",
        tag: "file",
        size: 26 * 1024 * 1024
      )
    end
    client.define_singleton_method(:download) do |**|
      downloaded = true
      raise "download should not run"
    end

    result = RecordingStudioDropbox::Attachable::Import.stub(:attachable_max_file_size, 10) do
      RecordingStudioDropbox::Attachable::Registration.stub(:client, ->(**) { client }) do
        RecordingStudioDropbox::Attachable::Import.remote_files(
          parent_recording: Object.new,
          attachments: ["id:file-1"],
          actor: Object.new
        )
      end
    end

    refute downloaded
    refute result.success?
    assert_equal RecordingStudioDropbox.file_too_large_message, result.error
    assert_includes result.error, "size limit"
  end


  def test_import_download_uses_downloaded_body_size_when_metadata_is_smaller
    body = "actual-file-bytes"
    metadata_size = 3
    downloaded = RecordingStudioDropbox::DownloadedFile.new(
      body: body,
      filename: "Brief.pdf",
      content_type: "application/pdf"
    )
    client = Object.new
    client.define_singleton_method(:fetch_file) do |**|
      RecordingStudioDropbox::Entry.new(
        id: "id:file-1",
        name: "Brief.pdf",
        path: "/Brief.pdf",
        tag: "file",
        size: metadata_size
      )
    end
    client.define_singleton_method(:download) do |**|
      downloaded
    end

    payload = RecordingStudioDropbox::Attachable::Import.stub(:attachable_max_file_size, 1_000_000) do
      RecordingStudioDropbox::Attachable::Registration.stub(:client, ->(**) { client }) do
        RecordingStudioDropbox::Attachable::Import.payload_for(
          Object.new,
          Object.new,
          { "id" => "id:file-1", "name" => "Brief.pdf" }
        )
      end
    end

    result = payload.fetch(:download).call

    assert_equal metadata_size, payload.fetch(:byte_size)
    assert_equal body.bytesize, result.fetch(:byte_size)
    refute_equal metadata_size, result.fetch(:byte_size)
  end

  def test_attachable_oauth_reports_needs_reconnect
    root = Object.new
    actor = Object.new
    seen = nil
    live = Object.new

    status = RecordingStudioOauth.stub(:connection_for, live) do
      RecordingStudioOauth.stub(
        :connection_status,
        lambda { |**kwargs|
          seen = kwargs
          :needs_reconnect
        }
      ) do
        RecordingStudioDropbox::Attachable::Oauth.connection_status(root: root, actor: actor)
      end
    end

    assert_equal :needs_reconnect, status
    assert_equal RecordingStudioDropbox::Attachable::Registration::PROVIDER_KEY, seen[:provider]
    assert_equal root, seen[:root]
    assert_equal actor, seen[:actor]
  end

  def test_chooser_access_probes_oauth_status_and_does_not_return_a_token
    root = Object.new
    actor = Object.new
    live = Object.new
    token_called = false
    statuses = []
    connections = []

    RecordingStudioDropbox::OauthToken.stub(:new, lambda { |**|
      token_called = true
      Object.new
    }) do
      RecordingStudioOauth.stub(
        :connection_status,
        lambda { |**kwargs|
          statuses << kwargs
          :active
        }
      ) do
        RecordingStudioOauth.stub(
          :connection_for,
          lambda { |**kwargs|
            connections << kwargs
            live
          }
        ) do
          result = RecordingStudioDropbox::Attachable::Registration.chooser_access(root: root, actor: actor)
          assert_nil result
        end
      end
    end

    refute token_called
    assert_equal [{ provider: :dropbox, root: root, actor: actor }], statuses
    assert_equal [{ provider: :dropbox, root: root, actor: actor }], connections
  end

  def test_chooser_access_raises_reconnect_when_oauth_is_missing
    error = RecordingStudioOauth.stub(:connection_status, :missing) do
      RecordingStudioOauth.stub(:connection_for, nil) do
        assert_raises(RecordingStudioDropbox::ReconnectRequired) do
          RecordingStudioDropbox::Attachable::Registration.chooser_access(root: Object.new, actor: Object.new)
        end
      end
    end

    assert_includes error.message, "reconnect"
  end
end
