# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_23_090004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "folders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "pages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "recording_studio_access_constraints", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.string "allowed_audiences", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.index ["action"], name: "index_recording_studio_access_constraints_on_action"
  end

  create_table "recording_studio_access_invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "recording_id", null: false
    t.string "email", null: false
    t.string "role", null: false
    t.string "token_digest", limit: 64, null: false
    t.string "manager_actor_type", null: false
    t.uuid "manager_actor_id", null: false
    t.string "accepted_by_actor_type"
    t.uuid "accepted_by_actor_id"
    t.datetime "expires_at", null: false
    t.datetime "last_sent_at", null: false
    t.datetime "accepted_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recording_id", "email"], name: "idx_rs_access_invitations_one_active", unique: true, where: "((accepted_at IS NULL) AND (revoked_at IS NULL))"
    t.index ["recording_id"], name: "index_recording_studio_access_invitations_on_recording_id"
    t.index ["token_digest"], name: "idx_rs_access_invitations_token_digest", unique: true
    t.check_constraint "accepted_at IS NULL OR revoked_at IS NULL", name: "access_invitations_not_accepted_and_revoked"
  end

  create_table "recording_studio_access_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.string "audience", null: false
    t.datetime "created_at", null: false
    t.index ["action"], name: "index_recording_studio_access_rules_on_action"
  end

  create_table "recording_studio_accesses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "actor_id", null: false
    t.string "actor_type", null: false
    t.datetime "created_at", null: false
    t.uuid "depends_on_recording_id"
    t.string "role", default: "view", null: false
    t.index ["actor_type", "actor_id", "role"], name: "index_recording_studio_accesses_on_actor_and_role"
    t.index ["actor_type", "actor_id"], name: "index_recording_studio_accesses_on_actor"
    t.index ["depends_on_recording_id"], name: "index_recording_studio_accesses_on_depends_on_recording_id"
  end

  create_table "recording_studio_attachable_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "attachment_kind", null: false
    t.string "original_filename", null: false
    t.string "content_type", null: false
    t.bigint "byte_size", null: false
    t.uuid "root_recording_id"
    t.text "caption"
    t.text "credit"
    t.text "alt_text"
    t.index ["attachment_kind", "content_type"], name: "idx_rs_attachable_kind_type"
    t.index ["attachment_kind"], name: "idx_on_attachment_kind_d683071625"
    t.index ["root_recording_id"], name: "index_rs_attachable_attachments_on_root_recording_id"
  end

  create_table "recording_studio_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.uuid "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.string "idempotency_key"
    t.uuid "impersonator_id"
    t.string "impersonator_type"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.uuid "previous_recordable_id"
    t.string "previous_recordable_type"
    t.uuid "recordable_id", null: false
    t.string "recordable_type", null: false
    t.uuid "recording_id", null: false
    t.index ["action", "occurred_at"], name: "index_rs_events_on_action_and_occurred_at"
    t.index ["actor_type", "actor_id", "occurred_at"], name: "index_rs_events_on_actor_and_occurred_at"
    t.index ["recording_id", "idempotency_key"], name: "index_recording_studio_events_on_recording_and_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["recording_id", "occurred_at", "created_at"], name: "index_rs_events_on_recording_and_timeline", order: { occurred_at: :desc, created_at: :desc }
    t.index ["recording_id"], name: "index_recording_studio_events_on_recording_id"
  end

  create_table "recording_studio_oauth_access_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "oauth_authorization_id", null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_used_at"
    t.index ["expires_at"], name: "index_recording_studio_oauth_access_tokens_on_expires_at"
    t.index ["oauth_authorization_id"], name: "idx_on_oauth_authorization_id_7313b03aba"
    t.index ["token_digest"], name: "index_recording_studio_oauth_access_tokens_on_token_digest", unique: true
  end

  create_table "recording_studio_oauth_authorization_codes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "oauth_authorization_id", null: false
    t.string "code_digest", null: false
    t.string "redirect_uri", null: false
    t.string "code_challenge"
    t.string "code_challenge_method"
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code_digest"], name: "idx_on_code_digest_bcebd970b4", unique: true
    t.index ["expires_at"], name: "index_recording_studio_oauth_authorization_codes_on_expires_at"
    t.index ["oauth_authorization_id"], name: "idx_on_oauth_authorization_id_4cb485335a"
  end

  create_table "recording_studio_oauth_authorizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "oauth_client_id", null: false
    t.string "manager_actor_type", null: false
    t.uuid "manager_actor_id", null: false
    t.uuid "manager_access_recording_id", null: false
    t.uuid "access_recording_id"
    t.string "role", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_recording_id"], name: "idx_on_access_recording_id_94e16371a2"
    t.index ["manager_access_recording_id"], name: "idx_on_manager_access_recording_id_ee8e9d6f9c"
    t.index ["manager_actor_type", "manager_actor_id"], name: "index_rs_oauth_authorizations_on_manager_actor"
    t.index ["oauth_client_id", "manager_actor_type", "manager_actor_id", "manager_access_recording_id"], name: "index_rs_oauth_authorizations_unique_active", unique: true, where: "(revoked_at IS NULL)"
    t.index ["oauth_client_id"], name: "index_recording_studio_oauth_authorizations_on_oauth_client_id"
    t.index ["revoked_at"], name: "index_recording_studio_oauth_authorizations_on_revoked_at"
  end

  create_table "recording_studio_oauth_clients", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "client_id", null: false
    t.string "client_secret_digest"
    t.jsonb "redirect_uris", default: [], null: false
    t.boolean "confidential", default: true, null: false
    t.string "api_key", default: "public", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "use_central_relay", default: false, null: false
    t.jsonb "allowed_return_patterns", default: [], null: false
    t.jsonb "exact_return_urls", default: [], null: false
    t.boolean "allow_registration", default: false, null: false
    t.string "session_token_provider"
    t.string "session_token_audience"
    t.text "session_token_secret_ciphertext"
    t.boolean "self_registered", default: false, null: false
    t.string "token_endpoint_auth_method", null: false
    t.index ["api_key"], name: "index_recording_studio_oauth_clients_on_api_key"
    t.index ["client_id"], name: "index_recording_studio_oauth_clients_on_client_id", unique: true
  end

  create_table "recording_studio_oauth_external_installs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "oauth_client_id", null: false
    t.string "provider", null: false
    t.string "external_id", null: false
    t.uuid "root_recording_id"
    t.string "connected_by_type"
    t.uuid "connected_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["connected_by_type", "connected_by_id"], name: "index_rs_oauth_external_installs_on_connected_by"
    t.index ["oauth_client_id", "provider", "external_id"], name: "index_rs_oauth_external_installs_on_client_provider_external", unique: true
    t.index ["provider", "external_id"], name: "index_rs_oauth_external_installs_on_provider_external"
    t.index ["root_recording_id"], name: "idx_on_root_recording_id_efcab19ee0"
  end

  create_table "recording_studio_oauth_outbound_connections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "provider_key", null: false
    t.uuid "root_recording_id"
    t.string "owner_actor_type"
    t.uuid "owner_actor_id"
    t.string "connected_by_type", null: false
    t.uuid "connected_by_id", null: false
    t.string "external_account_id"
    t.string "external_account_label"
    t.jsonb "granted_scopes", default: [], null: false
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "expires_at"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_key", "owner_actor_type", "owner_actor_id"], name: "idx_rs_oauth_outbound_live_user", unique: true, where: "((owner_actor_id IS NOT NULL) AND ((status)::text = ANY (ARRAY[('active'::character varying)::text, ('needs_reconnect'::character varying)::text])))"
    t.index ["provider_key", "root_recording_id"], name: "idx_rs_oauth_outbound_live_root", unique: true, where: "((root_recording_id IS NOT NULL) AND ((status)::text = ANY (ARRAY[('active'::character varying)::text, ('needs_reconnect'::character varying)::text])))"
    t.index ["provider_key"], name: "idx_on_provider_key_ad5bab8401"
    t.index ["root_recording_id"], name: "idx_on_root_recording_id_85327fae16"
    t.index ["status"], name: "index_recording_studio_oauth_outbound_connections_on_status"
    t.check_constraint "root_recording_id IS NOT NULL AND owner_actor_id IS NULL AND owner_actor_type IS NULL OR root_recording_id IS NULL AND owner_actor_id IS NOT NULL AND owner_actor_type IS NOT NULL", name: "chk_rs_oauth_outbound_owner"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'needs_reconnect'::character varying::text, 'revoked'::character varying::text])", name: "chk_rs_oauth_outbound_status"
  end

  create_table "recording_studio_oauth_outbound_handshakes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "nonce_digest", null: false
    t.string "provider_key", null: false
    t.string "owner_kind", null: false
    t.uuid "root_recording_id"
    t.string "actor_type", null: false
    t.uuid "actor_id", null: false
    t.text "code_verifier"
    t.string "return_to", default: "/", null: false
    t.datetime "expires_at", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_recording_studio_oauth_outbound_handshakes_on_expires_at"
    t.index ["nonce_digest"], name: "idx_rs_oauth_outbound_handshakes_nonce", unique: true
  end

  create_table "recording_studio_oauth_refresh_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "oauth_authorization_id", null: false
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.uuid "replaced_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_recording_studio_oauth_refresh_tokens_on_expires_at"
    t.index ["oauth_authorization_id"], name: "idx_on_oauth_authorization_id_a1e93340c5"
    t.index ["replaced_by_id"], name: "index_recording_studio_oauth_refresh_tokens_on_replaced_by_id"
    t.index ["token_digest"], name: "index_recording_studio_oauth_refresh_tokens_on_token_digest", unique: true
  end

  create_table "recording_studio_recordings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "parent_recording_id"
    t.uuid "recordable_id", null: false
    t.string "recordable_type", null: false
    t.uuid "root_recording_id"
    t.datetime "trashed_at"
    t.datetime "updated_at", null: false
    t.index ["parent_recording_id"], name: "idx_rs_attachable_parent_active", where: "(((recordable_type)::text = 'RecordingStudioAttachable::Attachment'::text) AND (trashed_at IS NULL))"
    t.index ["parent_recording_id"], name: "index_recording_studio_recordings_on_parent_recording_id"
    t.index ["recordable_type", "recordable_id", "parent_recording_id", "trashed_at"], name: "index_recording_studio_recordings_on_recordable_parent_trashed"
    t.index ["recordable_type", "recordable_id"], name: "index_recording_studio_recordings_on_recordable"
    t.index ["recordable_type", "recordable_id"], name: "index_rs_unique_root_recording_per_recordable", unique: true, where: "(parent_recording_id IS NULL)"
    t.index ["root_recording_id", "parent_recording_id"], name: "index_rs_recordings_on_root_and_parent"
    t.index ["root_recording_id", "recordable_type", "recordable_id"], name: "index_rs_recordings_on_root_and_recordable"
    t.index ["root_recording_id"], name: "idx_rs_attachable_root_active", where: "(((recordable_type)::text = 'RecordingStudioAttachable::Attachment'::text) AND (trashed_at IS NULL))"
    t.index ["root_recording_id"], name: "index_rs_recordings_on_root_recording"
  end

  create_table "recording_studio_root_switchable_selections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.string "device_browser"
    t.string "device_key", null: false
    t.string "device_label"
    t.string "device_platform"
    t.string "device_type"
    t.datetime "last_used_at", null: false
    t.uuid "root_recording_id", null: false
    t.string "scope_key", null: false
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.index ["actor_type", "actor_id", "device_key", "scope_key"], name: "idx_rs_root_switchable_actor_device_scope", unique: true, where: "(actor_id IS NOT NULL)"
    t.index ["device_key", "scope_key"], name: "idx_rs_root_switchable_anonymous_device_scope", unique: true, where: "(actor_id IS NULL)"
    t.index ["root_recording_id"], name: "idx_rs_root_switchable_root_recording"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workspaces", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "recording_studio_access_invitations", "recording_studio_recordings", column: "recording_id"
  add_foreign_key "recording_studio_events", "recording_studio_recordings", column: "recording_id"
  add_foreign_key "recording_studio_oauth_access_tokens", "recording_studio_oauth_authorizations", column: "oauth_authorization_id"
  add_foreign_key "recording_studio_oauth_authorization_codes", "recording_studio_oauth_authorizations", column: "oauth_authorization_id"
  add_foreign_key "recording_studio_oauth_authorizations", "recording_studio_oauth_clients", column: "oauth_client_id"
  add_foreign_key "recording_studio_oauth_external_installs", "recording_studio_oauth_clients", column: "oauth_client_id"
  add_foreign_key "recording_studio_oauth_external_installs", "recording_studio_recordings", column: "root_recording_id"
  add_foreign_key "recording_studio_oauth_outbound_connections", "recording_studio_recordings", column: "root_recording_id"
  add_foreign_key "recording_studio_oauth_outbound_handshakes", "recording_studio_recordings", column: "root_recording_id", on_delete: :cascade
  add_foreign_key "recording_studio_oauth_refresh_tokens", "recording_studio_oauth_authorizations", column: "oauth_authorization_id"
  add_foreign_key "recording_studio_recordings", "recording_studio_recordings", column: "parent_recording_id"
  add_foreign_key "recording_studio_recordings", "recording_studio_recordings", column: "root_recording_id"
end
