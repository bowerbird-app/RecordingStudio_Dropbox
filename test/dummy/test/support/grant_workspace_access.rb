# frozen_string_literal: true

module GrantWorkspaceAccess
  def grant_workspace_access!(root, actor: @user, role: :admin)
    result = if role.to_sym == :admin
      RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: actor)
    else
      RecordingStudioAccessible.grant_access(
        recording: root,
        actor: actor,
        role: role,
        manager_actor: @user
      )
    end
    raise result.error if result.failure?
  end
end
