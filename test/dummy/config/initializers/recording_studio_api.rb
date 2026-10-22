# frozen_string_literal: true

RecordingStudioApi.configure do |config|
  config.openapi_title = "Recording Studio API"
  # This dummy has no AdminRoot. Keep AdminApi parents empty so declaration
  # validation does not require an unregistered AdminRoot type.
  config.admin_root_recordable_type_names = []
  config.documentation_enabled = false
  config.rate_limit_oauth_enabled = false
  config.rate_limit_api_pre_auth_enabled = false
  config.rate_limit_api_enabled = false
  config.api_request_logging_enabled = false
  config.api_management_authorization_required = false
end
