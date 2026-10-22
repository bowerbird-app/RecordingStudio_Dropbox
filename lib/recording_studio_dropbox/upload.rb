# frozen_string_literal: true

module RecordingStudioDropbox
  class Upload
    def initialize(transport:)
      @transport = transport
    end

    def call(path:, io:, chunk_size:)
      first = io.read(chunk_size).to_s
      raise Error, "Dropbox upload content is empty" if first.empty?

      rest = io.read(chunk_size)
      if rest.nil? || rest.empty?
        simple_upload(path, first)
      else
        session_upload(path, first, rest, io, chunk_size)
      end
    end

    private

    def simple_upload(path, bytes)
      response = @transport.post_content(
        "/2/files/upload",
        arg: { path: path, mode: "add" },
        body: bytes
      )
      UploadedFile.new(entry: Entry.from_api(Transport.parse_json(response.body)))
    end

    def session_upload(path, first, second, io, chunk_size)
      continue_session(
        path,
        { id: start_session(first), offset: first.bytesize, chunk: second },
        io,
        chunk_size
      )
    end

    def continue_session(path, session, io, chunk_size)
      loop do
        next_chunk = io.read(chunk_size)
        last_chunk = next_chunk.nil? || next_chunk.empty?
        return finish(path, session[:id], session[:offset], session[:chunk]) if last_chunk

        append(session[:id], session[:offset], session[:chunk])
        session[:offset] += session[:chunk].bytesize
        session[:chunk] = next_chunk
      end
    end

    def start_session(first)
      start = @transport.post_content("/2/files/upload_session/start", arg: {}, body: first)
      session_id = Transport.parse_json(start.body)["session_id"]
      raise RequestError, "Dropbox upload session is missing a session id" if session_id.nil? || session_id.to_s.empty?

      session_id
    end

    def append(session_id, offset, chunk)
      @transport.post_content(
        "/2/files/upload_session/append_v2",
        arg: { cursor: { session_id: session_id, offset: offset }, close: false },
        body: chunk
      )
    end

    def finish(path, session_id, offset, chunk)
      response = @transport.post_content(
        "/2/files/upload_session/finish",
        arg: {
          cursor: { session_id: session_id, offset: offset },
          commit: { path: path, mode: "add" }
        },
        body: chunk
      )
      UploadedFile.new(entry: Entry.from_api(Transport.parse_json(response.body)))
    end
  end
end
