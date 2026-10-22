# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioDropbox::Configuration.new
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", timeout: 7)

    refute_respond_to @configuration, :unknown_key
    refute_respond_to @configuration, :timeout
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original, @configuration.to_h
  end

  def test_initialize_exposes_recording_studio_hooks
    assert_instance_of RecordingStudio::Hooks, @configuration.hooks
    assert_equal({ hooks: "RecordingStudio::Hooks" }, @configuration.to_h)
  end

  def test_configure_without_block_is_safe
    RecordingStudioDropbox.configure

    assert_kind_of RecordingStudioDropbox::Configuration, RecordingStudioDropbox.configuration
  end
end
