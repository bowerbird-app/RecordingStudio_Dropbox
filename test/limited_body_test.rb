# frozen_string_literal: true

require "test_helper"

class LimitedBodyTest < Minitest::Test
  def test_append_raises_the_shared_oversize_message
    limited = RecordingStudioDropbox::LimitedBody.new(4)

    error = assert_raises(ArgumentError) { limited.append("12345") }

    assert_equal RecordingStudioDropbox.file_too_large_message, error.message
    assert_includes error.message, "size limit"
  end
end
