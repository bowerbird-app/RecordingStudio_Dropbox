# frozen_string_literal: true

require "test_helper"

class ContractTest < Minitest::Test
  def test_access_token_is_the_public_token_type
    refute defined?(RecordingStudioDropbox::TokenProvider)
    assert_equal [[:req, :provider]], RecordingStudioDropbox::AccessToken.instance_method(:initialize).parameters
    assert RecordingStudioDropbox::AccessToken.method_defined?(:to_s)
  end

  def test_error_classes
    assert RecordingStudioDropbox::Error < StandardError
    assert RecordingStudioDropbox::ReconnectRequired < RecordingStudioDropbox::Error
    assert RecordingStudioDropbox::RequestError < RecordingStudioDropbox::Error
    refute defined?(RecordingStudioDropbox::ApiError)
    assert_equal(
      [[:key, :status], [:key, :code]],
      RecordingStudioDropbox::RequestError.instance_method(:initialize).parameters
    )
    assert RecordingStudioDropbox::RequestError.method_defined?(:status)
    assert RecordingStudioDropbox::RequestError.method_defined?(:code)
  end

  def test_page_shape
    refute defined?(RecordingStudioDropbox::Listing)
    assert_equal(
      [[:keyreq, :entries], [:keyreq, :next_cursor]],
      RecordingStudioDropbox::Page.instance_method(:initialize).parameters
    )
    page = RecordingStudioDropbox::Page.new(entries: [], next_cursor: nil)
    assert_equal [], page.entries
    assert_nil page.next_cursor
    refute page.more?
  end

  def test_downloaded_file_shape
    assert_equal(
      [[:keyreq, :body], [:keyreq, :filename], [:key, :content_type]],
      RecordingStudioDropbox::DownloadedFile.instance_method(:initialize).parameters
    )
    file = RecordingStudioDropbox::DownloadedFile.new(body: "x", filename: "a.pdf", content_type: "application/pdf")
    assert_equal "x", file.body
    assert_equal "a.pdf", file.filename
    assert_equal "application/pdf", file.content_type
    refute file.respond_to?(:bytes)
  end

  def test_client_signatures
    client = RecordingStudioDropbox::Client
    assert_equal [[:keyreq, :token_provider]], client.instance_method(:initialize).parameters
    assert_equal [[:key, :path], [:key, :cursor]], client.instance_method(:list_folder).parameters
    assert_equal(
      [[:keyreq, :query], [:key, :path], [:key, :cursor]],
      client.instance_method(:search).parameters
    )
    assert_equal [[:keyreq, :path]], client.instance_method(:metadata).parameters
    assert_equal [[:keyreq, :path]], client.instance_method(:download).parameters
    assert_equal(
      [[:keyreq, :path], [:keyreq, :content], [:key, :chunk_size]],
      client.instance_method(:upload).parameters
    )
  end

  def test_configure_returns_configuration
    result = RecordingStudioDropbox.configure

    assert_same RecordingStudioDropbox.configuration, result
  end
end
