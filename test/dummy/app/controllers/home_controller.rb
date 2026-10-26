class HomeController < ApplicationController
  def index
    @workspace = Workspace.find_by(name: "Studio Workspace")
    @root_recording = RecordingStudio.root_recording_for(@workspace) if @workspace
    @dropbox_connection = live_dropbox_connection
  end

  private

  def live_dropbox_connection
    return unless current_user && @root_recording

    RecordingStudioOauth.connection_for(
      provider: RecordingStudioDropbox::OauthProvider::KEY,
      root: @root_recording,
      actor: current_user
    )
  end
end
