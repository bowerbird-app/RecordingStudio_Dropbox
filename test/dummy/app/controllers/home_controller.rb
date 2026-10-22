class HomeController < ApplicationController
  def index
    @dropbox_connection = live_dropbox_connection
  end

  private

  def live_dropbox_connection
    return unless current_user

    RecordingStudioOauth::OutboundConnection.live.for_provider(RecordingStudioDropbox::OauthProvider::KEY).find_by(
      owner_actor: current_user
    )
  end
end
