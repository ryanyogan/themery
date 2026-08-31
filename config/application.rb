require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Themery
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks middleware])

    # Where the bare git repos the stock omarchy client clones live. In
    # production this must sit on the persistent volume (set REPOS_ROOT).
    config.x.repos_root = ENV.fetch("REPOS_ROOT") {
      File.join(ENV.fetch("DATA_ROOT") { Rails.root.join("storage").to_s }, "repos")
    }

    # Git traffic (clone/pull of hosted theme repos) is static-file serving
    # plus one telemetry write — it skips sessions, cookies, and CSRF by
    # running ahead of nearly the whole middleware stack.
    require_relative "../lib/middleware/git_dumb_protocol"
    config.middleware.insert_after ActionDispatch::Executor, GitDumbProtocol

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
