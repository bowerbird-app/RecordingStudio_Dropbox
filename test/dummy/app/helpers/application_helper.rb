module ApplicationHelper
  def dropbox_home_subtitle
    if @dropbox_connection.nil?
      "Connect Dropbox to copy files into this workspace."
    elsif @dropbox_connection.needs_reconnect?
      "Dropbox needs another look-in before we can copy files."
    else
      "Dropbox is connected. Disconnect any time."
    end
  end

  def dummy_page_nav(title:, subtitle: nil, back_url: nil, back_label: "Home")
    content_for(:title, title)
    content_for(:subtitle, subtitle) if subtitle.present?

    if back_url.present?
      flat_pack_page_nav(
        round: true,
        style: :default,
        back_href: back_url,
        back_tooltip: back_label
      )
    end

    recording_studio_page_nav_right do
      concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
      concat render(
        FlatPack::Button::Component.new(
          text: "Sign out",
          style: :ghost,
          size: :md,
          href: main_app.destroy_user_session_path,
          data: { turbo_method: :delete }
        )
      )
    end
  end
end
