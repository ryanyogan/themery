require "open3"
require "resolv"

module Publishing
  # Copies an author's existing GitHub-hosted theme into the pipeline. The
  # URL is author-controlled, so this is locked down well past what the
  # omarchy client itself accepts: https only (no scp-style, no file/ftp,
  # no credential-helper syntax), public addresses only (checked after DNS
  # resolution, so a hostname can't launder a private IP), shallow, no
  # submodules, and killed on a wall clock. The clone's working tree is the
  # only thing kept — its .git never reaches the pipeline.
  class GitImport
    Result = Data.define(:errors, :commit) do
      def ok? = errors.empty?
    end

    TIMEOUT_SECONDS = 60

    def self.fetch(url, into:)
      errors = validate_url(url)
      return Result.new(errors:, commit: nil) if errors.any?

      clone(url, Pathname(into))
    end

    # The remote's current HEAD sha without cloning — what the hourly sync
    # compares against a theme's recorded upstream_commit.
    def self.remote_head(url)
      return nil if validate_url(url).any?

      env = {
        "PATH" => ENV["PATH"], "HOME" => Dir.tmpdir,
        "GIT_ALLOW_PROTOCOL" => "https", "GIT_TERMINAL_PROMPT" => "0",
        "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_SYSTEM" => "/dev/null"
      }
      stdout, _stderr, status = Open3.capture3(
        env, "timeout", "20", "git", "ls-remote", "--", url, "HEAD", unsetenv_others: true
      )
      status.success? ? stdout[/\A\h{40,64}/] : nil
    end

    def self.validate_url(url)
      uri = URI.parse(url.to_s)
      return [ "Import URL must start with https://" ] unless uri.is_a?(URI::HTTPS) && uri.host.present?
      return [ "Import URL cannot carry credentials" ] if uri.userinfo.present?

      addresses = Resolv.getaddresses(uri.host).filter_map { |a| IPAddr.new(a) rescue nil }
      return [ "Import URL's host could not be resolved" ] if addresses.empty?
      if addresses.any? { |ip| ip.private? || ip.loopback? || ip.link_local? }
        return [ "Import URL resolves to a private address" ]
      end

      []
    rescue URI::InvalidURIError
      [ "Import URL is not a valid URL" ]
    end

    def self.clone(url, dest)
      env = {
        "PATH" => ENV["PATH"], "HOME" => Dir.tmpdir,
        "GIT_ALLOW_PROTOCOL" => "https", "GIT_TERMINAL_PROMPT" => "0",
        "GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_CONFIG_SYSTEM" => "/dev/null"
      }
      # followRedirects=false closes the SSRF hole the DNS pre-check can't:
      # a public host 3xx-ing the clone to an internal address. The pre-check
      # still matters (it rejects directly-private hosts with a clear error),
      # but the redirect refusal is the enforcement.
      argv = %W[timeout #{TIMEOUT_SECONDS} git -c http.followRedirects=false
                clone --quiet --depth 1 --single-branch
                --no-recurse-submodules -- #{url} #{dest}]

      _stdout, stderr, status = Open3.capture3(env, *argv, unsetenv_others: true)
      if status.exitstatus == 124
        return Result.new(errors: [ "Cloning #{url} took longer than #{TIMEOUT_SECONDS}s and was stopped" ], commit: nil)
      end
      return Result.new(errors: [ "Could not clone #{url}: #{stderr.lines.first&.strip}" ], commit: nil) unless status.success?

      head, _stderr, head_status = Open3.capture3(env, "git", "-C", dest.to_s, "rev-parse", "HEAD", unsetenv_others: true)
      FileUtils.rm_rf(dest.join(".git"))
      Result.new(errors: [], commit: head_status.success? ? head.strip : nil)
    end
  end
end
