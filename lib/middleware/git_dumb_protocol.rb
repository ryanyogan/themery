# Serves the Hosted Repos to stock git clients over the dumb HTTP protocol
# (ADR 0001): every response is a static file under a bare repo, kept current
# by `update-server-info` at publish time. Sits ahead of cookies, session,
# and CSRF — a clone is a burst of file fetches and deserves none of that.
#
# The request shapes git actually makes (measured against git 2.55):
#
#   GET /:name.git/info/refs?service=git-upload-pack   every operation
#   GET /:name.git/HEAD                                every operation
#   GET /:name.git/objects/info/packs                  when loose lookup fails
#   GET /:name.git/objects/pack/pack-<sha>.{idx,pack}  the actual content
#   GET /:name.git/objects/<2>/<38>                    loose objects
#   GET /:name.git/objects/info/{http-,}alternates     mandatory 404s
#
# Telemetry: with one pack per approved Version, fetching the theme's base
# pack means a fresh install and fetching only newer packs means an update,
# so pack fetches are recorded raw here and classified at recount time.
# The alternates paths MUST 404 — a 200 would redirect git's object lookup.
class GitDumbProtocol
  REPO_PATH = %r{\A/([a-z0-9][a-z0-9_-]*)\.git(/.*)\z}
  SERVABLE = %r{\A/(
    HEAD |
    info/refs |
    objects/info/packs |
    objects/pack/pack-\h{40,64}\.(?:pack|idx) |
    objects/\h{2}/\h{38,62}
  )\z}x

  def initialize(app)
    @app = app
    @files = Rack::Files.new(HostedRepo.root.to_s)
  end

  def call(env)
    name, file = parse(env)
    return @app.call(env) unless name

    if file == "info/refs"
      # The one dynamic decision: a repo is cloneable only while its Theme
      # has an approved Version — checked here, the single entry point of
      # every git operation, never assumed elsewhere.
      return not_found unless Theme.published.exists?(name: name)
    elsif file.nil?
      return not_found
    end

    record_pack_fetch(env, name, file)
    serve(env, name, file)
  end

  private
    def parse(env)
      return nil unless %w[GET HEAD].include?(env[Rack::REQUEST_METHOD])
      repo = REPO_PATH.match(env[Rack::PATH_INFO]) or return nil
      file = SERVABLE.match(repo[2])
      [ repo[1], file && file[1] ]
    end

    def serve(env, name, file)
      @files.call(env.merge(Rack::PATH_INFO => "/#{name}.git/#{file}"))
    end

    def record_pack_fetch(env, name, file)
      pack = file[%r{\Aobjects/pack/(pack-\h+)\.pack\z}, 1] or return
      theme_id = Theme.where(name:).pick(:id) or return

      FetchEvent.insert(
        { theme_id:, pack_name: pack, client_hash: client_hash(env), created_at: Time.current },
        returning: false
      )
    rescue StandardError => e
      Rails.logger.warn("fetch telemetry skipped: #{e.class}: #{e.message}")
    end

    # Stable per-client-per-day, reversible by nobody: enough to dedupe a
    # multi-pack fetch burst without storing addresses.
    def client_hash(env)
      ip = env["action_dispatch.remote_ip"]&.to_s || env["REMOTE_ADDR"].to_s
      Digest::SHA256.hexdigest([ ip, Date.current, Rails.application.secret_key_base ].join(":")).first(16)
    end

    def not_found
      [ 404, { "content-type" => "text/plain" }, [ "not found\n" ] ]
    end
end
