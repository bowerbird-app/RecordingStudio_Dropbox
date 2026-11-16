# frozen_string_literal: true

RecordingStudioApi.configure do |config|
  config.openapi_title = "Recording Studio API"
  # This dummy has no AdminRoot. The default name is AdminRoot, which is not
  # loaded here. An empty list keeps AdminApi undeclared. recording_studio.rb
  # registers that type only when this list is present.
  config.admin_root_recordable_type_names = []
  config.documentation_enabled = false
  config.rate_limit_oauth_enabled = false
  config.rate_limit_api_pre_auth_enabled = false
  config.rate_limit_api_failed_auth_enabled = false
  config.rate_limit_api_enabled = false
  config.api_request_logging_enabled = false
  config.api_management_authorization_required = false
end
