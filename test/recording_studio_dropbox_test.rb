# frozen_string_literal: true

require "test_helper"

class RecordingStudioDropboxTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.4.3", ::RecordingStudioDropbox::VERSION
    gemspec = File.read(File.expand_path("../recording_studio_dropbox.gemspec", __dir__))
    ruby_version = File.read(File.expand_path("../.ruby-version", __dir__)).strip

    assert_includes gemspec, 'spec.required_ruby_version = ">= 3.3.0"'
    refute_includes gemspec, '">= 3.3.12"'
    assert_equal "3.3.12", ruby_version
  end

  def test_dummy_database_names_match_devcontainer
    database_yml = File.read(File.expand_path("dummy/config/database.yml", __dir__))
    compose = File.read(File.expand_path("../.devcontainer/docker-compose.yml", __dir__))

    assert_includes database_yml, "recording_studio_dropbox_development"
    assert_includes database_yml, "recording_studio_dropbox_test"
    refute_includes database_yml, "app_development"
    refute_includes database_yml, "app_test"
    assert_includes compose, "recording_studio_dropbox_development"
    refute_includes compose, "app_development"
  end

  def test_picker_launcher_harness_does_not_skip_when_node_is_missing
    source = File.read(File.expand_path("dropbox_picker_launcher_test.rb", __dir__))

    refute_includes source, "skip "
    assert_includes source, "assert node_available?"
    assert_includes source, "assert provider_launchers_path"
  end

  def test_dummy_dropbox_tests_share_grant_workspace_access
    helper = File.read(File.expand_path("dummy/test/support/grant_workspace_access.rb", __dir__))
    test_helper = File.read(File.expand_path("dummy/test/test_helper.rb", __dir__))
    copies = Dir[
      File.expand_path("dummy/test/**/*.rb", __dir__)
    ].reject { |path| path.end_with?("support/grant_workspace_access.rb") }.select do |path|
      File.read(path).include?("def grant_workspace_access!")
    end

    assert_includes helper, "def grant_workspace_access!"
    assert_includes test_helper, "include GrantWorkspaceAccess"
    assert_empty copies, "grant_workspace_access! must live in one helper (found #{copies.join(', ')})"
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioDropbox::Engine
  end

  def test_attachable_add_on_uses_public_hooks
    attachable = File.read(File.expand_path("../lib/recording_studio_dropbox/attachable.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_dropbox/engine.rb", __dir__))
    registration = File.read(File.expand_path("../lib/recording_studio_dropbox/attachable/registration.rb", __dir__))
    bootstrap = File.read(
      File.expand_path("../app/controllers/recording_studio_dropbox/attachable/bootstrap_controller.rb", __dir__)
    )
    launcher = File.read(
      File.expand_path("../app/javascript/recording_studio_dropbox/dropbox_picker_launcher.js", __dir__)
    )

    assert_includes engine, "ActiveSupport.on_load(:recording_studio_attachable)"
    assert_includes engine, "Gem::Version.new(RecordingStudioAttachable::VERSION)"
    assert_includes attachable, "register_adapter_routes(:dropbox)"
    assert_includes attachable, 'mount RecordingStudioDropbox::Attachable::Engine, at: "/dropbox", as: :dropbox'
    attachable_engine = File.read(
      File.expand_path("../lib/recording_studio_dropbox/attachable/engine.rb", __dir__)
    )
    assert_includes attachable_engine, "register_upload_provider"
    assert_includes registration, "reconnect_error:"
    assert_includes registration, "connect:"
    refute_includes registration, "Adapter::ClientPicker"
    refute_includes registration, "Adapter::Configurable"
    assert_includes registration, "context:"
    refute_includes registration, "**"
    refute_includes bootstrap, "except(:connect)"
    assert_includes bootstrap, "provider_connect_payload"
    assert_includes launcher, 'from "recording_studio_attachable/provider_launchers"'
  end

  def test_gemspec_pins_recording_studio_4_2
    gemspec = File.read(File.expand_path("../recording_studio_dropbox.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", ">= 4.2", "< 7"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_oauth", ">= 0.17.0", "< 1.0"'
    refute_includes gemspec, 'spec.add_dependency "recording_studio_attachable"'
  end

  def test_gemspec_excludes_cursor_config
    spec = Gem::Specification.load(File.expand_path("../recording_studio_dropbox.gemspec", __dir__))
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }

    assert_empty cursor_files, "gemspec must not package .cursor/ (got #{cursor_files.inspect})"
    assert_includes spec.homepage, "RecordingStudio_Dropbox"
  end

  def test_gitignore_covers_coverage_output
    gitignore = File.read(File.expand_path("../.gitignore", __dir__))

    assert_includes gitignore, "coverage/"
    assert_includes gitignore, "test/dummy/coverage/"
  end

  def test_cursor_environment_is_repo_managed_without_snapshot
    path = File.expand_path("../.cursor/environment.json", __dir__)
    json = JSON.parse(File.read(path))

    assert_equal "recording-studio-dropbox", json["name"]
    assert_equal ".cursor/install.sh", json["install"]
    assert_equal ".cursor/start.sh", json["start"]
    refute json.key?("snapshot"), "snapshot pins a Personal build and skips install"
    refute json.key?("agentCanUpdateSnapshot")
  end

  def test_cursor_install_still_fetches_skills
    install_script = File.read(File.expand_path("../.cursor/install.sh", __dir__))

    assert_includes install_script, "fetch-skills.sh"
    refute_includes install_script, "Writing dummy master.key from RAILS_MASTER_KEY"
    refute_includes install_script, "Dummy credentials"
  end

  def test_dummy_does_not_read_rails_credentials
    dummy_root = File.expand_path("dummy", __dir__)
    credentials_path = File.join(dummy_root, "config/credentials.yml.enc")
    gitignore = File.read(File.expand_path("../.gitignore", __dir__))

    refute File.exist?(credentials_path)
    refute File.exist?(File.expand_path("dummy_credentials_test.rb", __dir__))
    refute File.exist?(File.join(dummy_root, "test/credentials_test.rb"))
    assert_includes gitignore, "test/dummy/config/master.key"
    assert_includes gitignore, "config/master.key"

    initializer = File.read(File.join(dummy_root, "config/initializers/recording_studio_dropbox.rb"))
    assert_includes initializer, "Rails.application.credentials"
    assert_includes initializer, "dig(:recording_studio_oauth, :outbound, :dropbox)"
    refute_includes initializer, "DROPBOX_CLIENT_ID"
    refute_includes initializer, "DROPBOX_CLIENT_SECRET"
    refute_includes initializer, ":attachable"
    refute_includes initializer, "creds[:dropbox]"

    Dir.glob("#{dummy_root}/**/*.{rb,yml,erb}").each do |path|
      next if path.end_with?("config/initializers/recording_studio_dropbox.rb")

      File.foreach(path) do |line|
        next if line.match?(/\A\s*#/)

        refute_includes(
          line,
          "Rails.application.credentials",
          "#{path.delete_prefix("#{dummy_root}/")} reads Rails.application.credentials"
        )
      end
    end
  end

  def test_dummy_gemfile_pins_verified_6x_github_tags
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v6.3.0"'
    refute_includes gemfile, 'tag: "v4.7.0"'
    refute_includes gemfile, 'tag: "v4.6.0"'
    refute_includes gemfile, 'tag: "v4.5.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.23.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.12.0", require: false'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.11.0"'
    refute_includes gemfile, 'tag: "v0.10.0"'
    refute_includes gemfile, 'tag: "v0.15.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable"'
    assert_includes gemfile, 'tag: "v0.22.0"'
    refute_includes gemfile, 'ref: "900cc3a169e26f0e4604e1acb3cbc1d81281aa87"'
    refute_includes gemfile, 'tag: "v0.21.1"'
    refute_includes gemfile, 'tag: "v0.15.0"'
    refute_includes gemfile, 'tag: "v0.10.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.11.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_cache", tag: "v0.6.0"'
    refute_includes gemfile, 'tag: "v0.5.0"'
    refute_includes gemfile, 'tag: "v0.5.1"'
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.329"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_Oauth", tag: "v0.20.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.7.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_api", tag: "v0.17.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_admin", tag: "v2.7.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_site_settings", tag: "v0.5.2"'
    assert_includes gemfile, 'gem "net-ssh", ">= 7.3.8"'
    refute_includes gemfile, "recording_studio/v3.0.0"
    refute_includes gemfile, 'tag: "v4.4.0"'
    refute_includes gemfile, 'tag: "v4.3.0"'
    refute_includes gemfile, 'tag: "v4.2.2"'
    refute_includes gemfile, 'tag: "v4.2.1"'
    refute_includes gemfile, 'tag: "v4.2.0"'
    refute_includes gemfile, 'tag: "v0.9.1"'
    refute_includes gemfile, 'tag: "v0.8.0"'
    refute_includes gemfile, 'tag: "v0.1.213"'
    refute_includes gemfile, 'tag: "v0.1.177"'
    refute_includes gemfile, 'tag: "v0.1.133"'
    refute_includes gemfile, 'tag: "0.3.1"'
  end

  def test_dummy_schema_includes_accessible_depends_on_recording_id
    schema = File.read(File.expand_path("dummy/db/schema.rb", __dir__))
    assert_includes schema, 'create_table "recording_studio_attachable_attachments"'
    assert_includes schema, 'create_table "active_storage_blobs"'
    assert_includes schema, 'create_table "recording_studio_oauth_outbound_connections"'
    assert_includes schema, 'create_table "recording_studio_oauth_outbound_handshakes"'
    assert_includes schema, 't.string "plugin_key"'
    migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20260911024811_add_depends_on_recording_id_to_recording_studio_accesses.rb",
        __dir__
      )
    )

    assert_includes schema, 't.uuid "depends_on_recording_id"'
    assert_includes schema, "index_recording_studio_accesses_on_depends_on_recording_id"
    assert_includes migration, "add_column :recording_studio_accesses, :depends_on_recording_id, :uuid"
    assert_includes schema, 'create_table "recording_studio_access_invitations"'
    assert_includes schema, "idx_rs_access_invitations_token_digest"
    invitation_migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20261001000011_create_recording_studio_access_invitations.rb",
        __dir__
      )
    )
    assert_includes invitation_migration, "create_table :recording_studio_access_invitations"
    assert_includes schema, 't.string "role", default: "view", null: false'
    refute_includes schema, 't.integer "role", default: 0, null: false'
    role_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_change_recording_studio_accesses_role_to_string.rb", __dir__)
    ).max
    assert role_migration, "expected role-column migration in dummy db/migrate"
    assert_includes File.read(role_migration), "change_column :recording_studio_accesses, :role, :string"

    assert_includes schema, 'create_table "recording_studio_access_constraints"'
    assert_includes schema, 'create_table "recording_studio_access_rules"'
    assert_includes schema, "index_recording_studio_access_constraints_on_action"
    assert_includes schema, "index_recording_studio_access_rules_on_action"
    constraint_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_create_recording_studio_access_constraints.rb", __dir__)
    ).max
    rule_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_create_recording_studio_access_rules.rb", __dir__)
    ).max
    assert constraint_migration, "expected access constraints migration in dummy db/migrate"
    assert rule_migration, "expected access rules migration in dummy db/migrate"
    assert_includes File.read(constraint_migration), "create_table :recording_studio_access_constraints"
    assert_includes File.read(rule_migration), "create_table :recording_studio_access_rules"
  end

  def test_template_does_not_ship_copied_core_hooks_or_base_service
    refute File.exist?(File.expand_path("../lib/recording_studio_dropbox/hooks.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_dropbox/services/base_service.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_dropbox/services/example_service.rb", __dir__))
    refute File.exist?(
      File.expand_path("../lib/generators/recording_studio_dropbox/migrations/migrations_generator.rb", __dir__)
    )
    refute File.exist?(
      File.expand_path("../lib/generators/recording_studio_dropbox/install/INSTALL.md", __dir__)
    )
    refute File.exist?(
      File.expand_path("../app/controllers/recording_studio_dropbox/application_controller.rb", __dir__)
    )
    refute File.exist?(File.expand_path("dummy/app/javascript/controllers/hello_controller.js", __dir__))
    refute File.exist?(File.expand_path("dummy/.github/workflows/ci.yml", __dir__))
    refute File.exist?(File.expand_path("dummy/.github/dependabot.yml", __dir__))
    refute File.exist?(File.expand_path("dummy/install_page.html", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/makeup_artist/custom_examples/.keep", __dir__))
    refute File.exist?(File.expand_path("dummy/app/models/concerns/.keep", __dir__))
    refute File.exist?(File.expand_path("dummy/script/.keep", __dir__))
    refute File.exist?(File.expand_path("dummy/vendor/.keep", __dir__))
    refute File.exist?(File.expand_path("dummy/vendor/javascript/.keep", __dir__))
    refute File.exist?(File.expand_path("dummy/app/controllers/concerns/.keep", __dir__))
    refute Dir.exist?(File.expand_path("../.github/agents", __dir__))
  end

  def test_example_capability_is_not_shipped
    refute File.exist?(File.expand_path("../lib/recording_studio_dropbox/capabilities/example.rb", __dir__))
  end

  def test_dummy_app_uses_recording_studio_default_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "recording_studio_layout"
    refute_includes controller_source, "UsesDefaultLayout"
    assert_includes controller_source, '"recording_studio/default_layout"'
    assert_includes controller_source, "devise_controller? ? \"application\""
    refute_includes controller_source, "flat_pack_sidebar"
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))
  end

  def test_dummy_login_layout_keeps_flatpack_assets_without_tight_main_offset
    application_layout = File.read(File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__))

    assert_includes application_layout, '<html data-theme="rounded">'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/rich_text"'
    assert_includes application_layout, "javascript_importmap_tags"
    assert_includes application_layout, "min-h-screen"
    refute_includes application_layout, "mt-28"
    refute_includes application_layout, "flat_pack_sidebar"
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, "../../../vendor/engines/flat_pack/app/components"
    assert_includes tailwind_source, "../../../vendor/engines/recording_studio/app/views"
    refute_includes tailwind_source, "vendor/bundle/**/flatpack/app/components"
    refute_includes tailwind_source, "recordingstudio-*"
    refute_includes tailwind_source, "@theme"
    refute_includes tailwind_source, ":root {"
    refute_includes tailwind_source, "--color-fp-primary"

    head_partial = File.read(
      File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__)
    )
    assert_includes head_partial, 'stylesheet_link_tag "flat_pack/application"'

    rake_task = File.read(File.expand_path("dummy/lib/tasks/tailwindcss.rake", __dir__))
    assert_includes rake_task, "FlatPack::Engine.root"
    assert_includes rake_task, "RecordingStudio::Engine.root"
    assert_includes rake_task, "tailwindcss:link_engine_sources"
  end

  def test_recording_studio_keeps_strict_recordable_declarations_enabled
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "config.require_recordable_declarations = true"
    recordable_types = initializer_source[/config\.recordable_types = \[(.*?)\]/m, 1].scan(/"([^"]+)"/).flatten
    assert_equal [
      "Workspace",
      "Folder",
      "Page",
      "RecordingStudioSiteSettings::SiteSetting",
      "RecordingStudioAttachable::Attachment",
      "RecordingStudio::Access",
      "RecordingStudioApi::AdminApi",
      "RecordingStudioApi::ApiAccessToken",
      "RecordingStudioApi::ApiClient",
      "RecordingStudioApi::ApiCredential"
    ], recordable_types
    refute_includes initializer_source, "config.include_children"
    refute_includes initializer_source, "config.features."
    refute_includes initializer_source, "v3"
  end

  def test_dummy_readme_explains_dummy_app_purpose
    readme_path = File.expand_path("dummy/README.md", __dir__)
    readme_source = File.read(readme_path)

    assert_includes readme_source, "This Rails app exists to validate the Recording Studio Dropbox gem"
    assert_includes readme_source, "/recording_studio"
    assert_includes readme_source, "redirects to `/`"
    assert_includes readme_source, "fake Dropbox provider"
    assert_includes readme_source, "/attachments/upload"
    assert_includes readme_source, "recording_studio_oauth.outbound.dropbox"
    refute_includes readme_source, "DROPBOX_CLIENT_ID"
    refute_includes readme_source, "attachable.dropbox"
    refute_includes readme_source, "flat_pack_sidebar"
  end

  def test_product_readme_describes_the_dropbox_client
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "RecordingStudioDropbox::Client"
    assert_includes readme, "OauthToken"
    assert_includes readme, "root plugin"
    assert_includes readme, "RecordingStudioDropbox.register_oauth_provider"
    assert_includes readme, "kind: :root"
    assert_includes readme, "connection_for"
    assert_includes readme, "both Oauth `client_id` and `client_secret` are blank"
    assert_includes readme, "recording_studio_oauth.outbound.dropbox.client_id"
    assert_includes readme, "recording_studio_oauth.outbound.dropbox.client_secret"
    assert_includes readme, "ReconnectRequired"
    assert_includes readme, "register_upload_provider"
    assert_includes readme, "config.enabled"
    assert_includes readme, "config.client_id"
    assert_includes readme, "`content_type` is always `nil`"
    assert_includes readme, "## Shared shape with Google Drive"
    assert_includes readme, "`search` is not folder-scoped: it has no `path:`."
    assert_includes readme, "does not take `content_type:`"
    assert_includes readme, 'tag: "v0.4.3"'
    assert_includes readme, 'tag: "v0.20.0"'
    assert_includes readme, 'tag: "v0.22.0"'
    assert_includes readme, "The gemspec requires RecordingStudioOauth `>= 0.17.0`, `< 1.0`"
    assert_includes readme, "dummy app pins"
    refute_includes readme, 'tag: "v0.21.0"'
    refute_includes readme, 'tag: "v0.17.0"'
    refute_includes readme, "900cc3a169e26f0e4604e1acb3cbc1d81281aa87"
    refute_includes readme, "Planned Attachable wiring"
    refute_includes readme, "Dummy credentials"
    refute_includes readme, "Template Demo"
    refute_includes readme, "ExampleService"
    refute_includes readme, "RecordingStudio_gem_template"
  end

  def test_dummy_home_page_describes_the_dropbox_client
    view_path = File.expand_path("dummy/app/views/home/index.html.erb", __dir__)
    view_source = File.read(view_path)

    assert_includes view_source, 'title: "Dropbox"'
    assert_includes view_source, "Connect Dropbox"
    assert_includes view_source, "Reconnect Dropbox"
    assert_includes view_source, "Disconnect"
    assert_includes view_source, "outbound_connect_path"
    assert_includes view_source, "dummy_page_nav"
    refute_includes view_source, "Template Demo"
    refute_includes view_source, "FlatPack::Breadcrumb::Component"
    refute_includes view_source, "FlatPack::Card::Component"
  end

  def test_dummy_docs_pages_use_minimal_flatpack_documentation_components
    docs_view_paths = Dir[File.expand_path("dummy/app/views/docs/*.html.erb", __dir__)].reject do |view_path|
      File.basename(view_path).start_with?("_")
    end
    refute_empty docs_view_paths

    docs_view_paths.each do |view_path|
      view_source = File.read(view_path)

      assert_includes view_source, "dummy_page_nav"
      assert_includes view_source, "subtitle:"
      refute_includes view_source, "FlatPack::PageTitle::Component"
      refute_includes view_source, "FlatPack::Card::Component"
      refute_includes view_source, "FlatPack::Breadcrumb::Component"
    end

    methods_view = File.read(File.expand_path("dummy/app/views/docs/methods.html.erb", __dir__))
    assert_includes methods_view, "FlatPack::SectionTitle::Component"
    assert_includes methods_view, "FlatPack::CodeBlock::Component"

    gem_views_view = File.read(File.expand_path("dummy/app/views/docs/gem_views.html.erb", __dir__))
    assert_includes gem_views_view, "FlatPack::Table::Component"
    refute_includes gem_views_view, "FlatPack::List::Component"

    recordable_types_view = File.read(File.expand_path("dummy/app/views/docs/recordable_types.html.erb", __dir__))
    assert_includes recordable_types_view, "FlatPack::List::Component"
    refute_includes recordable_types_view, "v3 parent/root"

    recordings_tree_view = File.read(File.expand_path("dummy/app/views/docs/recordings_tree.html.erb", __dir__))
    assert_includes recordings_tree_view, "FlatPack::Tree::Component"
    refute_includes recordings_tree_view, "Current structure"
    refute_includes recordings_tree_view, "This tree is generated from RecordingStudio::Recording records"
  end

  def test_dummy_recordings_tree_view_omits_structure_section_copy
    recordings_tree_view = File.read(File.expand_path("dummy/app/views/docs/recordings_tree.html.erb", __dir__))

    assert_includes recordings_tree_view, 'title: "Recordings tree"'
    assert_includes recordings_tree_view, "FlatPack::Tree::Component"
    recording_tree_partial = File.read(File.expand_path("dummy/app/views/docs/_recording_tree_node.html.erb", __dir__))
    assert_includes recording_tree_partial, "parent_builder.node"
    refute_includes recordings_tree_view, "Current structure"
    refute_includes recordings_tree_view, "This tree is generated from RecordingStudio::Recording records"
  end

  def test_engine_does_not_ship_a_home_view
    view_path = File.expand_path("../app/views/recording_studio_dropbox/home/index.html.erb", __dir__)

    refute File.exist?(view_path)
  end
end
