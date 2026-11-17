# frozen_string_literal: true

module RecordingStudioDropbox
  module Api
    module Descriptions
      def self.prose(text) = text.tr("\n", " ").squeeze(" ").strip.freeze

      CURSOR = {
        type: :string, required: false, allow_blank: true,
        description: prose(<<~TEXT)
          Page token returned as next_cursor. Leave it out on the first call.
          Pass the previous next_cursor to read the next page. When this is set,
          the other inputs on this call are ignored.
        TEXT
      }.freeze
      PAGE_SIZE = {
        type: :integer, required: false,
        description: prose(<<~TEXT)
          How many entries to return on the first page. Leave it out to use the
          host default, which is 25 unless the host changed it. This value is ignored when cursor is set.
        TEXT
      }.freeze
      LIST_RECORDING_ID = {
        type: :string, required: true, allow_blank: false,
        description: prose(<<~TEXT)
          Id of any recording in this workspace. The call uses that recording to find
          the workspace Dropbox account, and it checks that you can upload on this
          recording. Use a recording id you already have.
        TEXT
      }.freeze
      IMPORT_RECORDING_ID = {
        type: :string, required: true, allow_blank: false,
        description: prose(<<~TEXT)
          Id of the recording that will hold the copied files. You need upload
          permission on this recording. The files come from the Dropbox account
          connected to this recording's workspace. Use a recording id you already have.
        TEXT
      }.freeze
      LIST = prose(<<~TEXT)
        List files and folders in the Dropbox account connected to this workspace.
        Use this to open one folder before you call dropbox.import. Use dropbox.search
        when you have text to match and you do not know the folder. Pass any recording
        id in the workspace as recording_id. You need upload permission on that recording.
        Set path to the folder you want to open. Leave path blank, or pass a single slash,
        to list the top level. The call returns entries and next_cursor. Each entry has id,
        name, path, folder, and size. folder is true for a folder and false for a file.
        size is the file size in bytes, and it is null for a folder. next_cursor is null
        when this page is the last one. Pass that next_cursor back as cursor to read the
        next page. When cursor is set, path and page_size are ignored. Pass an entry id
        to dropbox.import only when folder is false. The call fails when this workspace
        has no Dropbox connected, when recording_id is missing or unknown, or when you
        lack upload permission.
      TEXT
      SEARCH = prose(<<~TEXT)
        Search files and folders in the Dropbox account connected to this workspace.
        Use this when you have text to match and you do not know the folder. Use
        dropbox.list to open one folder. Search is not limited to a folder. This tool
        has no path argument. Pass any recording id in the workspace as recording_id.
        You need upload permission on that recording. query is the text to match. The
        call returns entries and next_cursor. Each entry has id, name, path, folder, and
        size. Those are the same fields dropbox.list returns. folder is true for a folder
        and false for a file. size is the file size in bytes, and it is null for a folder.
        next_cursor is null when this page is the last one. Pass that next_cursor back as
        cursor to read the next page. When cursor is set, query and page_size are ignored.
        Pass an entry id to dropbox.import only when folder is false. The call fails when
        this workspace has no Dropbox connected, when recording_id is missing or unknown,
        or when you lack upload permission.
      TEXT
      IMPORT = prose(<<~TEXT)
        Copy one or more Dropbox files into storage and attach the copies to a recording.
        The copy is stored on the recording. A later change in Dropbox does not change
        that stored file. Call dropbox.list or dropbox.search first, then pass ids from
        entries whose folder value is false. recording_id is the recording that will
        hold the files. You need upload permission on that recording. attachments lists
        the files to copy. Each item is a Dropbox id string, or an object with an id.
        The workspace Dropbox account must already be connected. The call returns
        attachments. Each item has id, name, and kind. id is the new recording id for
        that attachment. It is not the Dropbox id you passed in. name is the file name.
        kind is the attachment kind on the new record. The call fails when Dropbox is
        not connected, when you lack upload permission, when recording_id is missing or
        unknown, when attachments is empty, or when a file is over the size limit. A
        folder id fails. Import downloads the path, and a folder has no file bytes to copy.
      TEXT
      ATTACHMENTS = {
        type: :array, required: true,
        description: prose(<<~TEXT)
          Dropbox files to copy. Each item is an id string, or an object with an id.
          Take the id from a dropbox.list or dropbox.search entry whose folder value is
          false. Other keys on the object are ignored. At least one id is required.
        TEXT
      }.freeze
      PATH = {
        type: :string, required: false, allow_blank: true,
        description: prose(<<~TEXT)
          Folder to list. Leave it blank, or pass a single slash, for the top level.
          To open a folder, pass that entry's path. A value that starts with id: also works.
          This value is ignored when cursor is set.
        TEXT
      }.freeze
      QUERY = {
        type: :string, required: true, allow_blank: false,
        description: prose(<<~TEXT)
          Text to match across the whole connected Dropbox account. The search is not
          limited to one folder. This value is ignored when cursor is set.
        TEXT
      }.freeze
    end
  end
end
