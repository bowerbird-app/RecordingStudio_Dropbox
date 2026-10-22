# frozen_string_literal: true

require "test_helper"

class TokenProviderTest < Minitest::Test
  def test_reads_a_callable
    provider = RecordingStudioDropbox::TokenProvider.new(-> { "sl.token" })

    assert_equal "sl.token", provider.access_token
  end

  def test_reads_access_token_from_an_object
    source = Object.new
    source.define_singleton_method(:access_token) { "from-object" }
    provider = RecordingStudioDropbox::TokenProvider.new(source)

    assert_equal "from-object", provider.access_token
  end

  def test_blank_token_raises_reconnect_required
    provider = RecordingStudioDropbox::TokenProvider.new(-> { "  " })

    assert_raises(RecordingStudioDropbox::ReconnectRequired) { provider.access_token }
  end

  def test_wrap_returns_an_existing_provider
    original = RecordingStudioDropbox::TokenProvider.new(-> { "tok" })

    assert_same original, RecordingStudioDropbox::TokenProvider.wrap(original)
  end
end
