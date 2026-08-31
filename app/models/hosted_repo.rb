require "open3"

# The bare git repository Themery maintains for a Theme — the thing the stock
# omarchy client clones and pulls (ADR 0001). Invariants this class owns:
#
#   * Nothing unapproved ever enters the repo: publish! is called only at
#     Approval, with the normalized tree.
#   * History is append-only. There is no method that rewrites main, on
#     purpose: the client updates with plain `git pull`, so any rewrite
#     bricks every installed user until they reinstall.
#   * One pack per approved Version: auto-gc is disabled at creation and
#     publish! runs an incremental `repack -d` (never `-a`), because the
#     pack layout IS the install/update telemetry — a fresh clone fetches
#     the base pack, an updating client only the newer ones.
#   * `update-server-info` runs last, so dumb-protocol clients never see
#     refs pointing at objects that aren't fetchable yet.
#
# All git invocations are argv arrays with a scrubbed environment — repo
# contents are author-controlled input.
class HostedRepo
  class CommandFailed < StandardError; end

  COMMITTER_NAME = "Themery"
  COMMITTER_EMAIL = "publisher@themery.invalid"

  def self.root
    Pathname(Rails.configuration.x.repos_root)
  end

  def self.for(theme) = new(theme.name)

  attr_reader :path

  def initialize(name)
    @path = self.class.root.join("#{name}.git")
  end

  def exists? = path.join("HEAD").exist?

  def create!
    path.mkpath
    git "init", "--bare", "--initial-branch=main", "--quiet"
    git "config", "gc.auto", "0"
    git "config", "gc.autoPackLimit", "0"
    git "update-server-info"
  end

  # Commits the tree as the new tip of main, tags it, packs it, and republishes
  # the dumb-protocol metadata. Returns the name of the pack this Version's
  # objects landed in, for the telemetry mapping.
  def publish!(tree_root, tag:, message:)
    create! unless exists?

    packs_before = pack_names
    commit = commit_tree(tree_root, message:)
    git "update-ref", "refs/heads/main", commit
    git "update-ref", "refs/tags/#{tag}", commit
    git "repack", "-d", "--quiet"
    git "update-server-info"
    (pack_names - packs_before).first
  end

  def clone_url(host)
    "#{host}/#{path.basename}"
  end

  private
    def commit_tree(tree_root, message:)
      Dir.mktmpdir("themery-index") do |scratch|
        index = File.join(scratch, "index")
        git "add", "--all", env: { "GIT_WORK_TREE" => tree_root.to_s, "GIT_INDEX_FILE" => index }
        tree = git("write-tree", env: { "GIT_INDEX_FILE" => index }).strip
        parent = begin
          git("rev-parse", "--verify", "--quiet", "refs/heads/main").strip
        rescue CommandFailed
          nil
        end
        args = [ "commit-tree", tree, "-m", message ]
        args.push("-p", parent) if parent
        git(*args).strip
      end
    end

    # Extensionless (pack-<sha>), matching what the serving middleware records.
    def pack_names
      objects = path.join("objects/pack")
      objects.directory? ? objects.glob("*.pack").map { |pack| pack.basename(".pack").to_s } : []
    end

    def git(*args, env: {})
      full_env = {
        "PATH" => ENV["PATH"],
        "HOME" => Dir.tmpdir,
        "GIT_DIR" => path.to_s,
        "GIT_AUTHOR_NAME" => COMMITTER_NAME, "GIT_AUTHOR_EMAIL" => COMMITTER_EMAIL,
        "GIT_COMMITTER_NAME" => COMMITTER_NAME, "GIT_COMMITTER_EMAIL" => COMMITTER_EMAIL,
        "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_SYSTEM" => "/dev/null"
      }.merge(env)

      stdout, stderr, status = Open3.capture3(full_env, "git", *args, unsetenv_others: true)
      raise CommandFailed, "git #{args.first}: #{stderr.presence || status}" unless status.success?
      stdout
    end
end
