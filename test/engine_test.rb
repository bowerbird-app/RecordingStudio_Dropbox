# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    RecordingStudioDropbox.configure
    RecordingStudioDropbox.configuration.hooks.clear!
  end

  def teardown
    RecordingStudioDropbox.configuration.hooks.clear!
  end

  def test_before_and_after_initialize_initializers_run_hooks
    before_called = false
    after_called = false

    RecordingStudioDropbox.configuration.hooks.before_initialize { |_engine| before_called = true }
    RecordingStudioDropbox.configuration.hooks.after_initialize { |_engine| after_called = true }

    find_initializer("recording_studio_dropbox.before_initialize").block.call(Object.new)
    find_initializer("recording_studio_dropbox.after_initialize").block.call(Object.new)

    assert before_called
    assert after_called
  end

  def test_load_config_runs_on_configuration_hook
    hook_called = false
    hook_payload = nil
    RecordingStudioDropbox.configuration.hooks.on_configuration do |cfg|
      hook_called = true
      hook_payload = cfg
    end

    xcfg = Struct.new(:recording_studio_dropbox).new({})
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        {}
      end
    end.new(app_config)

    find_initializer("recording_studio_dropbox.load_config").block.call(app)

    assert hook_called
    assert_equal RecordingStudioDropbox.configuration, hook_payload
  end

  def test_load_config_handles_missing_yaml
    xcfg = Struct.new(:recording_studio_dropbox).new({})
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        raise Errno::ENOENT
      end
    end.new(app_config)

    find_initializer("recording_studio_dropbox.load_config").block.call(app)

    assert_instance_of RecordingStudio::Hooks, RecordingStudioDropbox.configuration.hooks
  end

  def test_apply_model_extensions_adds_registered_methods_once
    model_class = Class.new do
      def self.name
        "ExampleRecord"
      end
    end

    RecordingStudioDropbox.configuration.hooks.extend_model(:ExampleRecord) do
      def dropbox_extension_method
        :applied
      end
    end

    RecordingStudioDropbox::Engine.apply_model_extensions(model_class)
    RecordingStudioDropbox::Engine.apply_model_extensions(model_class)

    assert_equal :applied, model_class.new.dropbox_extension_method
  end

  def test_apply_controller_extensions_matches_demodulized_name
    controller_class = Class.new do
      def self.name
        "Admin::DashboardController"
      end
    end

    RecordingStudioDropbox.configuration.hooks.extend_controller(:DashboardController) do
      def dropbox_controller_extension
        :applied
      end
    end

    RecordingStudioDropbox::Engine.apply_controller_extensions(controller_class)

    assert_equal :applied, controller_class.new.dropbox_controller_extension
  end

  private

  def find_initializer(name)
    RecordingStudioDropbox::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
