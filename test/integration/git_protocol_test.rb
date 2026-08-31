require "test_helper"
require "capybara"
require "open3"

# Seam 1, the contract that outranks every other test in this repo: a stock
# omarchy client must be able to `git clone` and `git pull` a Themery theme
# with no client changes at all (ADR 0001). So the centrepiece here is a real
# `git` binary talking to a real HTTP port served by a real Puma, with only
# what the middleware puts on disk to work from.
#
# Themes are given unique names because the bare repos live outside the test
# database, in one directory shared by every parallel worker.
class GitProtocolTest < ActionDispatch::IntegrationTest
  # One Puma per process, booted on demand and reused by every test in it.
  def self.server
    @server ||= Capybara::Server.new(Rails.application, host: "127.0.0.1").boot
  end

  setup do
    HostedRepo.root.mkpath
    @repo_paths = []
  end

  teardown do
    @repo_paths.each { |path| FileUtils.rm_rf(path) }
  end

  # --- a real git client, a real port -------------------------------------

  test "a stock git client can clone a published theme and pull its next version" do
    theme = publish("good-theme.tar.gz")

    Dir.mktmpdir("themery-clone") do |dir|
      checkout = File.join(dir, "theme")

      out, status = run_git("clone", clone_url(theme), checkout)

      assert_predicate status, :success?, "git clone failed: #{out}"
      assert_path_exists File.join(checkout, "colors.toml")
      assert_path_exists File.join(checkout, "backgrounds/1-dawn.png")
      assert_match(/#1e1e2e/, File.read(File.join(checkout, "colors.toml")))
      assert_equal "v1", run_git("-C", checkout, "tag").first.strip

      assert_operator FetchEvent.where(theme:).count, :>, 0, "the clone was not counted"
      installing = FetchEvent.where(theme:).distinct.pluck(:client_hash)

      publish("denied-files-theme.tar.gz", theme_name: theme.name, changelog: "Adds icons.")

      out, status = run_git("-C", checkout, "pull", "--tags", "--quiet")

      assert_predicate status, :success?, "git pull failed: #{out}"
      assert_path_exists File.join(checkout, "icons.theme"), "the pulled version's new file is missing"
      assert_not File.exist?(File.join(checkout, "neovim.lua")), "a stripped file reached a git client"
      assert_equal %w[v1 v2], run_git("-C", checkout, "tag").first.split

      # The real client installed and then updated from one address, so it is
      # one install. A second client that only ever saw the newer pack is an
      # update — recount is the single place that judgement is made.
      FetchEvent.recount!(theme)
      theme.reload

      assert_equal 1, theme.installs_count
      assert_equal 0, theme.updates_count

      FetchEvent.create!(theme:, client_hash: "an0therclient00", pack_name: theme.versions.order(:number).last.pack_name)
      FetchEvent.recount!(theme)
      theme.reload

      assert_equal 1, theme.installs_count
      assert_equal 1, theme.updates_count
      assert_not_includes installing, "an0therclient00"
    end
  end

  # --- the request shapes git makes ---------------------------------------

  test "info/refs advertises main and the version tags" do
    theme = publish("good-theme.zip")

    get "/#{theme.name}.git/info/refs?service=git-upload-pack"

    assert_response :success
    assert_match(/refs\/heads\/main/, response.body)
    assert_match(/refs\/tags\/v1/, response.body)
  end

  test "HEAD points at main" do
    theme = publish("good-theme.zip")

    get "/#{theme.name}.git/HEAD"

    assert_response :success
    assert_equal "ref: refs/heads/main\n", response.body
  end

  test "a HEAD request carries the headers a git client needs" do
    theme = publish("good-theme.zip")

    head "/#{theme.name}.git/HEAD"

    assert_response :success
    assert_equal "21", response.headers["content-length"]
  end

  test "the pack index and pack are served and the pack fetch is counted" do
    theme = publish("good-theme.zip")
    pack = theme.versions.sole.pack_name

    get "/#{theme.name}.git/objects/info/packs"

    assert_response :success
    assert_match(/^P #{Regexp.escape(pack)}\.pack$/, response.body)

    get "/#{theme.name}.git/objects/pack/#{pack}.idx"

    assert_response :success

    assert_difference -> { FetchEvent.where(theme:, pack_name: pack).count }, 1 do
      get "/#{theme.name}.git/objects/pack/#{pack}.pack"
    end
    assert_response :success
  end

  # --- what must never be served ------------------------------------------

  test "the alternates files 404 even though the repo exists" do
    theme = publish("good-theme.zip")

    %w[objects/info/alternates objects/info/http-alternates].each do |file|
      get "/#{theme.name}.git/#{file}"

      assert_response :not_found, "#{file} must 404 — a 200 redirects git's object lookup"
    end
  end

  test "repo internals outside the served set 404" do
    theme = publish("good-theme.zip")

    %w[config description packed-refs hooks/post-update refs/heads/main logs/HEAD].each do |file|
      get "/#{theme.name}.git/#{file}"

      assert_response :not_found, "#{file} is not part of the dumb protocol surface"
    end
  end

  test "an unknown repo 404s" do
    get "/nosuchtheme.git/info/refs?service=git-upload-pack"

    assert_response :not_found
  end

  test "a theme with no approved version is not cloneable even once its repo exists" do
    theme = users(:one).themes.create!(name: unique_name)
    theme.versions.create!(number: 1, mode: "dark", colors: { "background" => "#1e1e2e", "foreground" => "#cdd6f4" })
    track(HostedRepo.for(theme)).create!

    get "/#{theme.name}.git/info/refs?service=git-upload-pack"

    assert_response :not_found

    assert_predicate theme.versions.sole, :pending?
  end

  test "a real git client is refused an unapproved theme" do
    theme = users(:one).themes.create!(name: unique_name)
    theme.versions.create!(number: 1, mode: "dark", colors: { "background" => "#1e1e2e", "foreground" => "#cdd6f4" })
    track(HostedRepo.for(theme)).create!

    Dir.mktmpdir("themery-clone") do |dir|
      out, status = run_git("clone", clone_url(theme), File.join(dir, "theme"))

      assert_not status.success?, "an unapproved theme must not be cloneable: #{out}"
    end
  end

  private
    # Archive in, published Hosted Repo out — the whole publish path, because
    # the git contract is only worth testing on artifacts the pipeline built.
    def publish(archive, theme_name: unique_name, user: users(:one), changelog: nil)
      path = file_fixture("archives/#{archive}")
      submission = user.submissions.create!(kind: "archive_upload", theme_name:, changelog:)
      submission.archive.attach(io: path.open("rb"), filename: path.basename.to_s, content_type: "application/gzip")
      Publishing::Pipeline.process(submission)
      submission.reload

      assert_predicate submission, :accepted?, "publish fixture failed: #{submission.error_report.inspect}"
      track(HostedRepo.for(submission.theme))
      Publishing::Release.approve(submission.version)
      submission.theme.reload
    end

    def track(repo)
      @repo_paths << repo.path
      repo
    end

    def unique_name = "repo-#{SecureRandom.hex(6)}"

    def clone_url(theme)
      server = self.class.server
      "http://#{server.host}:#{server.port}/#{theme.name}.git"
    end

    def run_git(*argv)
      env = {
        "PATH" => ENV["PATH"], "HOME" => Dir.tmpdir, "GIT_TERMINAL_PROMPT" => "0",
        "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_SYSTEM" => "/dev/null"
      }
      stdout, stderr, status = Open3.capture3(env, "git", *argv, unsetenv_others: true)
      [ stdout + stderr, status ]
    end
end
