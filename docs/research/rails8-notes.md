# Rails 8 notes for Themery

Researched 2026-08-31. Target stack: Rails 8.1, Hotwire (Turbo + Stimulus via importmap), SQLite +
Solid Queue/Cache/Cable, Propshaft, no Node, Active Storage on local disk, single-service Railway deploy.

Source tags per fact:
- `[docs]` — Context7 fetch of official guides / gem docs
- `[src]` — read directly from `rails/rails` v8.1.3.1 (or the named gem tag) on GitHub
- `[api]` — rubygems.org API
- `[mem]` — from training data, not verified against docs. Treat as needs-checking.

---

## 0. Versions (2026-08-31)

| Gem | Latest stable | Source |
|---|---|---|
| **rails** | **8.1.3.1** (released 2026-07-29) | `[api]` |
| turbo-rails | 2.0.23 | `[api]` |
| stimulus-rails | 1.3.4 | `[api]` |
| solid_queue | 1.7.0 | `[api]` |
| solid_cache | 1.0.10 | `[api]` |
| solid_cable | 4.0.2 | `[api]` |
| propshaft | 1.3.2 | `[api]` |
| image_processing | 2.0.3 | `[api]` |
| sqlite3 | 2.9.6 | `[api]` |
| puma | 8.0.2 | `[api]` |
| thruster | 0.1.26 | `[api]` |
| kamal | 2.12.0 | `[api]` |

Rails 8.1 requires Ruby >= 3.2.0 `[api]`. Local Ruby is 3.4.7 — fine.
Rails 8.1 shipped October 2025 `[docs]`. Rails gem is NOT installed on this box (`gem list rails` empty).

Note: the Gemfile line the generator writes for `image_processing` is `~> 1.2` `[src]`, but the
current release is 2.0.3 `[api]` — bump it deliberately if you want v2.

---

## 1. `rails new` — flags vs defaults

### Defaults in Rails 8.1 (nothing to pass)
All from `[src]` `railties/lib/rails/generators/rails/app/{app_base,app_generator}.rb` @ v8.1.3.1:

| Thing | Default | Flag to change |
|---|---|---|
| Database | `sqlite3` | `-d/--database` (enum) |
| Asset pipeline | **Propshaft** (gem added unless skipped) | `-A/--skip-asset-pipeline` |
| JavaScript | **importmap** (`JAVASCRIPT_OPTIONS = importmap bun webpack esbuild rollup`) | `-j/--javascript` |
| Hotwire | on (turbo-rails + stimulus-rails) | `--skip-hotwire` |
| Solid trifecta | **on** — cache, queue, cable | `--skip-solid` |
| jbuilder | on | `--skip-jbuilder` |
| Kamal | on | `--skip-kamal` |
| Thruster | on | `--skip-thruster` |
| Dockerfile | on | `--skip-docker` |
| GitHub CI files | on | `--skip-ci` |
| rubocop / brakeman / bundler-audit | on | `--skip-rubocop` / `--skip-brakeman` / `--skip-bundler-audit` |
| System tests (capybara + selenium-webdriver) | on | `--skip-system-test` |
| CSS | none (plain CSS) | `-c/--css` = `tailwind bootstrap bulma postcss sass` |

**No Node is required by default.** importmap needs no runtime `[src]`. And `--css tailwind` also needs
no Node: the generator picks the standalone `tailwindcss-rails` gem when there's no JS runtime
(`if !using_js_runtime? && options[:css] == "tailwind"` → `GemfileEntry.floats "tailwindcss-rails"`,
then `rails_command "tailwindcss:install"`) `[src]`.

`using_js_runtime?` is true if you skip importmap OR pick a `--css` other than `tailwind`/`sass` `[src]` —
so `--css postcss/bootstrap/bulma` WOULD drag in Node. Pick `tailwind` or plain CSS.

### `--skip-solid` also skips cache and cable
`--skip-solid` desc: "Skip Solid Cache, Queue, and Cable setup" `[src]`, confirmed by the caching guide:
"This flag skips all parts of the Solid Trifecta... If you wish to use some components but not others,
they can be installed separately." `[docs]`

Skipping Solid is what pulls in Redis: the generator adds redis only when
`options[:skip_solid] && !(skip_action_cable && skip_active_job)` `[src]`. Keep Solid → no Redis. Good.

### What `--skip-kamal` actually changes (important, non-obvious)
`[src]` — three separate effects, none of them just "don't write deploy.yml":

1. Drops `gem "kamal"` from the Gemfile and skips `config/deploy.yml`.
2. **Uncomments `config.assume_ssl = true` and `config.force_ssl = true`** in
   `config/environments/production.rb`. With Kamal they are left commented (Kamal/Thruster terminates
   TLS itself). This is exactly right for Railway, which terminates TLS at its edge proxy — you want
   both on.
3. **Changes `config/database.yml`**: with Kamal, production SQLite paths are hardcoded to
   `storage/production.sqlite3` etc. (Kamal mounts `storage/` as a volume). With `--skip-kamal` the
   production `database:` lines are **commented out** with a warning that you must point them at a
   persistent disk. You have to fill them in. See §7.

### Recommended invocation for Themery

```bash
rails new themery \
  --database=sqlite3 \
  --css=tailwind \
  --skip-kamal \
  --skip-jbuilder
```

Rationale:
- `sqlite3`, importmap, Propshaft, Hotwire, Solid trifecta are all already the defaults — don't pass flags for them `[src]`.
- `--skip-kamal` — deploying on Railway; also flips force_ssl/assume_ssl on for you `[src]`.
- `--skip-jbuilder` — no JSON API surface planned.
- `--css=tailwind` — optional; only if you want Tailwind. Node-free via tailwindcss-rails `[src]`.

Optional extras to consider:
- `--skip-thruster` — Thruster is a Puma-fronting proxy giving X-Sendfile accel, asset caching and
  compression `[docs]`. It's harmless on Railway and genuinely useful for serving Propshaft assets and
  Active Storage disk files; **keep it** unless you want the Dockerfile simpler. `[mem]` for the
  "harmless on Railway" judgement.
- `--skip-docker` — only if you plan to use Railway's Nixpacks/Railpack builder instead of the
  generated Dockerfile. Railway will use the Dockerfile if present. `[mem]`
- `--skip-ci` — 8.1 also generates `config/ci.rb` + `bin/ci` (see §9); the GitHub workflow is the part
  `--skip-ci` removes. `[docs]` for Local CI, `[src]` for the flag desc.

Do **not** pass `-J/--skip-javascript` — that would remove importmap and break Turbo/Stimulus.

---

## 2. `bin/rails generate authentication`

### Exactly what it generates (v8.1.3.1)
`[src]` `railties/lib/rails/generators/rails/authentication/authentication_generator.rb`:

Files:
- `app/models/session.rb`, `app/models/user.rb`, `app/models/current.rb`
- `app/controllers/sessions_controller.rb`, `app/controllers/passwords_controller.rb`
- `app/controllers/concerns/authentication.rb`
- `app/channels/application_cable/connection.rb` — **only if Action Cable is loaded** (this is new
  relative to the 8.0 guide listing; it wires Turbo Streams auth to the session cookie)
- `app/mailers/passwords_mailer.rb` + `reset.html.erb` / `reset.text.erb` — only if Action Mailer loaded
- Views (skipped with `--api`): `app/views/sessions/new.html.erb`,
  `app/views/passwords/new.html.erb`, `app/views/passwords/edit.html.erb`
- `test/mailers/previews/passwords_mailer_preview.rb` `[docs]`

Mutations:
- injects `include Authentication` into `ApplicationController` `[src]`
- routes: `resources :passwords, param: :token` and `resource :session` `[src]`
- uncomments/adds `gem "bcrypt"` and bundles `[src]`
- two migrations `[src]`:
  - `CreateUsers  email_address:string!:uniq password_digest:string!`
  - `CreateSessions user:references ip_address:string user_agent:string`

Flags: `--api` (no views, API controllers) `[src]`.

There is **no `--skip-*`** for password reset — you get it whether you want it or not.

### The generated code (verbatim shapes worth knowing)

`app/models/user.rb` `[src]`:
```ruby
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
```

`app/models/current.rb` `[src]`:
```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
```
So `Current.user` is a delegation through `Current.session` — there is no `Current.user=`.

`app/controllers/concerns/authentication.rb` `[src]` — key API surface:
- class method `allow_unauthenticated_access(**options)` → `skip_before_action :require_authentication`
- `authenticated?` (helper_method), `require_authentication` (before_action, on by default everywhere)
- `resume_session` → `Current.session ||= Session.find_by(id: cookies.signed[:session_id])`
- `start_new_session_for(user)` → creates a `Session` row with user_agent/ip, sets
  `cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }`
- `terminate_session`, `after_authentication_url`

Sessions are **DB-backed rows**, not Rails session cookies. Killing a `Session` record logs the user
out everywhere on that device immediately. `[src]`

`app/channels/application_cable/connection.rb` `[src]`:
```ruby
identified_by :current_user
def connect = set_current_user || reject_unauthorized_connection
# set_current_user finds Session by cookies.signed[:session_id]
```

### Idiomatic email verification on top

Rails 8.1 ships a **guide for exactly this**: `guides.rubyonrails.org/sign_up_and_settings.html` `[docs]`.
The idiomatic pattern is `generates_token_for` (no `confirmation_token` column, no Devise):

```ruby
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  normalizes :email_address, with: ->(e) { e.strip.downcase }

  generates_token_for :email_confirmation, expires_in: 7.days do
    unconfirmed_email          # token invalidated as soon as this value changes
  end

  def confirm_email
    update(email_address: unconfirmed_email, unconfirmed_email: nil)
  end
end
```
`[docs]`

Mailer `[docs]`:
```ruby
class UserMailer < ApplicationMailer
  def email_confirmation
    @token = params[:user].generate_token_for(:email_confirmation)
    mail to: params[:user].unconfirmed_email
  end
end
```

Controller `[docs]`:
```ruby
class Email::ConfirmationsController < ApplicationController
  allow_unauthenticated_access

  def show
    user = User.find_by_token_for(:email_confirmation, params[:token])
    if user&.confirm_email
      flash[:notice] = "Your email has been confirmed."
    else
      flash[:alert] = "Invalid token."
    end
    redirect_to root_path
  end
end
```

Email-change flow uses `password_challenge` (from `has_secure_password`) `[docs]`:
```ruby
params.expect(user: [ :password_challenge, :unconfirmed_email ]).with_defaults(password_challenge: "")
```

**Migration shape**: add `unconfirmed_email:string` to `users` (nullable). The guide's model stores the
*pending* address in `unconfirmed_email` and promotes it into `email_address` on confirm — so
"verified" is implied by `unconfirmed_email.nil?` for changes. For **signup** verification you'd add
your own `verified_at:datetime` (or `email_verified_at`) and gate on it. `[mem]` — the guide covers the
change-email case; the signup-gating variant is an extrapolation.

### `admin` boolean

No generator support; do it plainly `[mem]`:
```bash
bin/rails generate migration AddAdminToUsers admin:boolean
```
```ruby
add_column :users, :admin, :boolean, null: false, default: false
```
Then a concern next to `Authentication`:
```ruby
module Administration
  extend ActiveSupport::Concern
  included { before_action :require_admin }
  private
    def require_admin
      head :forbidden unless Current.user&.admin?
    end
end
```
Idiomatic Rails 8 placement is a namespaced `Admin::BaseController` that `include`s it, mirroring how
the guide builds `Settings::BaseController` `[docs]` for the settings namespace.

Do NOT put `admin` in strong params anywhere. `[mem]`

---

## 3. Solid Queue in production (single server)

### Puma plugin — this is the single-server answer
The generated `config/puma.rb` already contains, verbatim `[src]`:
```ruby
# Run the Solid Queue supervisor inside of Puma for single-server deployments.
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]
```
So for Railway: **set `SOLID_QUEUE_IN_PUMA=1` as an env var** and jobs run inside the web process.
No second Railway service, no second container. Confirmed by solid_queue README: `plugin :solid_queue`
and the conditional form `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]` `[docs]`.

Separate process alternative: `bin/jobs` binstub `[src]` (`SolidQueue::Cli.start(ARGV)`), which the
install generator writes and chmods 0755. Use that only if you later split web/worker services.

Async-in-Puma mode also exists as `solid_queue_mode :async` in puma.rb, which runs workers/dispatchers
inside the Puma process and **ignores the `processes:` config option** `[docs]`.

### `config/queue.yml` (what `solid_queue:install` writes, v1.7.0) `[src]`
```yaml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 1

development: { <<: *default }
test:        { <<: *default }
production:  { <<: *default }
```
Tune via `JOB_CONCURRENCY`. Note `processes:` is ignored in async mode `[docs]`.

### `config/recurring.yml` `[src]`
Ships one production job out of the box:
```yaml
production:
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12
```
This is also the place to put Themery's own cron-ish work — no extra gem needed.

### Wiring in `production.rb`
The install generator rewrites `config/environments/production.rb` to `[src]`:
```ruby
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }
```
Matches the docs `[docs]`.

### Separate queue database
Yes, separate by default. `config/database.yml` production gets a `queue:` entry with
`migrations_paths: db/queue_migrate` `[src]` (see §7 for the SQLite-specific version). The docs show
the same pattern for a remote Postgres queue DB `[docs]`. Schema lives in `db/queue_schema.rb` `[src]`.

---

## 4. Solid Cable

### Does it need its own database?
**No, but the generated default gives it one.** Docs explicitly document both `[docs]`:
- with `connects_to: { database: { writing: cable } }` — separate cable DB
- "No connects_to, uses primary database" — single-database mode is supported

The `solid_cable:install` generator overwrites `config/cable.yml` with `force: true` `[src]` and writes
`[src]` (solid_cable v4.0.2):
```yaml
development:
  adapter: async
test:
  adapter: test
production:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

Gotcha: the *base Rails* `config/cable.yml` template still has `adapter: redis` for production `[src]` —
it's `solid_cable:install` (run by `run_solid` during `rails new`) that replaces it `[src]`. If you ever
regenerate config, check this file.

Dev is `adapter: async`, so cable updates triggered from a terminal `bin/rails console` will NOT show in
the browser — you must use the web console inside the dev process `[src]` (comment in the template).

### Full option list `[docs]`
```yaml
production:
  adapter: solid_cable
  connects_to: { database: { writing: cable } }
  polling_interval: 0.1.seconds     # how often to poll the messages table
  message_retention: 1.day          # autotrim window
  writer_batch_size: 4
  writer_batch_delay: 0.001.seconds
  autotrim: true
  silence_polling: true             # keep polling queries out of the log
  use_skip_locked: true
  trim_batch_size: 100
  reconnect_attempts: [0, 1, 5]
  encrypt: false
  encryption_context_properties: {}
```

For Themery on SQLite, `polling_interval: 0.1.seconds` against a local file is cheap. Keep
`silence_polling: true` (default in the template's fuller form) or logs will be noisy. `[mem]` for the
"cheap on SQLite" judgement.

---

## 5. Turbo Streams broadcasts from models (turbo-rails 2.0.23)

### `broadcasts_to` `[docs]`
```
broadcasts_to(stream, inserts_by: :append, target: broadcast_target_default, **rendering)
```
- `stream` — Symbol/String/Proc. Symbol = name of an association method on the record.
- `inserts_by:` — `:append` (default) or `:prepend`
- `target:` — DOM id for inserts; defaults to `broadcast_target_default` (the pluralized model name)
- `**rendering` — `partial:`, `locals:`, etc.

Sets up `after_create_commit` / `after_update_commit` / `after_destroy_commit`. `[docs]`

```ruby
class Message < ApplicationRecord
  belongs_to :conversation
  broadcasts_to :conversation, inserts_by: :prepend
end
```
```erb
<%= turbo_stream_from @conversation, :messages %>
```
`[docs]`

Conventions `[docs]` + `[mem]` for the naming details: create → `append`/`prepend` into
`target` (default `"messages"` for `Message`); update → `replace` targeting `dom_id(record)` (e.g.
`"message_1"`); destroy → `remove` targeting `dom_id(record)`. Partial defaults to
`app/views/messages/_message.html.erb` with local `message:`.

### `_later_to` variants `[mem]` — not returned by the doc fetch
`broadcast_replace_later_to`, `broadcast_append_later_to`, `broadcast_prepend_later_to`,
`broadcast_render_later_to` etc. enqueue `Turbo::Streams::ActionBroadcastJob` so rendering happens in
Solid Queue rather than in the request. The `_later` forms are what `broadcasts_to` uses internally for
create/update. `broadcast_remove_to` has **no** `_later` variant (nothing to render). Verify before relying on this.

Practical consequence for Themery: `_later` broadcasts need Solid Queue running, i.e. Railway must have
`SOLID_QUEUE_IN_PUMA` set, or broadcasts silently sit in the queue table. `[mem]`

### Turbo 8 morphing / broadcast refreshes `[docs]`
```ruby
class Theme < ApplicationRecord
  broadcasts_refreshes
end
```
API `[docs]`:
```
broadcasts_refreshes(stream = model_name.plural)
```
"Broadcasts refresh on create to plural stream, and on update/destroy to the model's own stream."

**Refreshes are automatically debounced**: multiple refresh broadcasts for the same stream inside a
**500ms window** are consolidated into one `[docs]`. That is the headline reason to prefer them — bulk
operations can't stampede the client.

Requires page morphing enabled in the layout `[mem]`:
```erb
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>
```
and `<%= turbo_stream_from @theme %>` (or the plural stream) in the view.

### When to prefer refreshes over hand-crafted stream actions
Guidance, mostly `[mem]` synthesised from the debouncing fact `[docs]`:

**Prefer `broadcasts_refreshes` when:**
- one model change affects several regions of the page (counts, sidebars, sort order, a list AND a header)
- ordering/filtering/pagination means the "correct" DOM position isn't derivable from the record alone
- you'd otherwise write three stream actions to keep one page consistent
- write volume is bursty — the 500ms debounce does the throttling for free

**Prefer explicit `broadcasts_to` / hand-written stream actions when:**
- the update is a single small, well-targeted fragment (a chat message appended to a log)
- the page is expensive to re-render and the target region is cheap
- the receiving client has local state morphing would disturb beyond what `data-turbo-permanent` covers

For Themery specifically: theme-list/gallery pages with sorting and counts are a natural
`broadcasts_refreshes` case; per-theme "install count" tickers are a natural `broadcast_replace_later_to`
case. `[mem]`

### Suppression
`Message.suppressing_turbo_broadcasts { ... }` disables broadcasts for a block `[docs]` — useful in
seeds, imports, and backfills.

---

## 6. Active Storage on local disk

### Default `config/storage.yml` (generated) `[src]`
```yaml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```
and `production.rb` gets `config.active_storage.service = :local` `[src]`; `test.rb` gets
`config.active_storage.service = :test` `[src]`.

### Custom root on a mounted volume
`root:` is plain ERB, so `[docs]` + `[mem]` for the ENV form:
```yaml
local:
  service: Disk
  root: <%= ENV.fetch("STORAGE_ROOT") { Rails.root.join("storage") } %>
```
Then on Railway set `STORAGE_ROOT=/data/storage` with a volume mounted at `/data`. `[mem]`

**Important**: this is the *same* `storage/` directory the SQLite databases default into `[src]`. On
Railway, mount ONE volume (e.g. `/data`) and point both the SQLite paths and the Active Storage root
inside it — otherwise you'll have uploads on the volume and the database on ephemeral container disk,
or vice versa. `[mem]`

### Variants with libvips
- `image_processing` gem is already in the generated Gemfile (unless `--skip-active-storage`) `[src]`.
- `config.active_storage.variant_processor = :vips` is set by **`load_defaults 7.0` and later**
  `[src]` `railties/.../configuration.rb`. So with `load_defaults 8.1` you get vips automatically.
- The library-level fallback default is `:mini_magick` `[src]` (`active_storage.rb`,
  `mattr_accessor :variant_processor, default: :mini_magick`) — that only applies if the app config is nil,
  i.e. if you don't call `load_defaults`. Don't worry about it, but don't be confused by the source.
- Valid values: `:mini_magick`, `:vips`, `:disabled` `[docs]`.
- Use `image_processing` macros, not raw ImageMagick geometry strings `[docs]`:
  - `resize: "100x100"` → `resize_to_fit: [100, 100]`
  - `resize: "100x100>"` → `resize_to_limit: [100, 100]`
  - `resize: "100x100^"` → `resize_to_fill: [100, 100]`

**System dependency**: libvips must be installed in the container. The Rails 8 generated Dockerfile
installs it (`libvips`) in the runtime stage. If you use Railway's Nixpacks builder instead of the
Dockerfile you must add libvips yourself. `[mem]` — verify against the generated Dockerfile once the app exists.

Recommended for Themery: named variants on the model, e.g.
```ruby
has_one_attached :preview do |attachable|
  attachable.variant :thumb, resize_to_limit: [400, 400], format: :webp
end
```
`[mem]`

---

## 7. SQLite production readiness

### What Rails 8 configures by itself
`[src]` `activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb` @ v8.1.3.1:

```ruby
DEFAULT_PRAGMAS = {
  "foreign_keys"       => true,
  "journal_mode"       => :wal,
  "synchronous"        => :normal,
  "mmap_size"          => 134217728,  # 128 MB
  "journal_size_limit" => 67108864,   # 64 MB
  "cache_size"         => 2000
}
```
Applied in `configure_connection`; you can override or add via a `pragmas:` hash in `database.yml`
(unknown pragma names just `warn`) `[src]`.

`busy_timeout` is **not** a pragma here — it comes from the `timeout:` config key (milliseconds),
applied as `@raw_connection.busy_handler_timeout = timeout` `[src]`. Adapter docs: "`:timeout`
(Integer): Timeout in milliseconds to use when waiting for a lock. (default: no wait)" `[src]`.
The generated `database.yml` sets `timeout: 5000` `[src]`.

Other adapter options worth knowing `[src]`:
- `statement_limit` — prepared statement cache per connection, default 1000
- `strict` — disallows double-quoted string literals; defaults to `strict_strings_by_default`
- `extensions` — array of SQLite extensions to load (requires sqlite3 gem >= 2.4.0)

### `pool:` was renamed to `max_connections:` in 8.1
`[src]` — compare the generated `config/databases/sqlite3.yml.tt`:
- v8.0.4: `pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>`
- v8.1.3.1: `max_connections: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>`

Don't copy an 8.0 database.yml verbatim into an 8.1 app.

### Generated production database.yml with `--skip-kamal`
`[src]` — note the paths are **commented out** and you must supply them:
```yaml
# SQLite3 write its data on the local filesystem, as such it requires
# persistent disks. If you are deploying to a managed service, you should
# make sure it provides disk persistence, as many don't.
production:
  primary:
    <<: *default
    # database: path/to/persistent/storage/production.sqlite3
  cache:
    <<: *default
    # database: path/to/persistent/storage/production_cache.sqlite3
    migrations_paths: db/cache_migrate
  queue:
    <<: *default
    # database: path/to/persistent/storage/production_queue.sqlite3
    migrations_paths: db/queue_migrate
  cable:
    <<: *default
    # database: path/to/persistent/storage/production_cable.sqlite3
    migrations_paths: db/cable_migrate
```

Four separate SQLite files: primary, cache, queue, cable. For Railway, fill in against the volume mount.
Suggested `[mem]`:
```yaml
production:
  primary:
    <<: *default
    database: <%= ENV.fetch("SQLITE_ROOT", "storage") %>/production.sqlite3
  cache:
    <<: *default
    database: <%= ENV.fetch("SQLITE_ROOT", "storage") %>/production_cache.sqlite3
    migrations_paths: db/cache_migrate
  # ... queue, cable likewise
```
with `SQLITE_ROOT=/data/sqlite` and a volume at `/data`.

### Still needed for a single-box production deploy `[mem]` — judgement, not fetched
- **Run migrations for all four databases.** `bin/rails db:migrate` handles primary; the solid schemas
  are loaded from `db/{cache,queue,cable}_schema.rb` — `db:prepare` is the safe entry point.
- **Backups.** Nothing built in. `sqlite3 .backup` or Litestream to object storage.
- **`RAILS_MAX_THREADS`** drives both Puma threads `[src]` and `max_connections` `[src]` — keep them
  aligned; the puma.rb comment says exactly this.
- **Single instance only.** SQLite + WAL on a mounted volume means you cannot horizontally scale the
  Railway service past 1 replica. Set replicas to 1 explicitly.
- **`config.force_ssl` / `assume_ssl`** — already on thanks to `--skip-kamal` `[src]`.
- Health check at `/up` exists and is excluded from logs (`config.silence_healthcheck_path = "/up"`) `[src]` —
  point Railway's healthcheck there.

---

## 8. Testing

### System tests: Capybara + Selenium headless Chrome (default)
`[src]` generated `test/application_system_test_case.rb`:
```ruby
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
end
```
Gemfile `group :test` gets `capybara` and `selenium-webdriver` `[src]`. No `webdrivers` gem — Selenium
Manager resolves the driver. Nothing to configure for headless; it's the generated default.

`test/test_helper.rb` `[src]`: `parallelize(workers: :number_of_processors)` and `fixtures :all`.
Minitest, not RSpec.

### Asserting Turbo Stream broadcasts
turbo-rails ships three test-helper families `[docs]`:
- `Turbo::TestAssertions` — auto-included into `ActiveSupport::TestCase`, for HTML fragments
- `Turbo::TestAssertions::IntegrationTestAssertions` — for `ActionDispatch::IntegrationTest`, adds status codes
- `Turbo::Broadcastable::TestHelper` — for broadcasts over Action Cable

Broadcast assertions `[docs]`:
```ruby
assert_turbo_stream_broadcasts(stream_name_or_object, count: nil, &block)
assert_no_turbo_stream_broadcasts(stream_name_or_object, &block)
capture_turbo_stream_broadcasts(stream_name_or_object, &block)  # => Array of stream elements
```

```ruby
class MessageTest < ActiveSupport::TestCase
  test "broadcasts on create" do
    assert_turbo_stream_broadcasts "messages" do
      Message.create!(content: "Hello")
    end
  end

  test "counts" do
    assert_turbo_stream_broadcasts "messages", count: 2 do
      Message.create!(content: "A"); Message.create!(content: "B")
    end
  end

  test "composite stream" do
    assert_turbo_stream_broadcasts [conversation, :messages] do
      message.broadcast_append_to conversation, :messages
    end
  end

  test "inspect payload" do
    streams = capture_turbo_stream_broadcasts "messages" do
      message.broadcast_replace_to "messages"
    end
    assert_equal "replace",   streams.first["action"]
    assert_equal "message_1", streams.first["target"]
  end

  test "suppression" do
    assert_no_turbo_stream_broadcasts "messages" do
      Message.suppressing_turbo_broadcasts { Message.create!(content: "Silent") }
    end
  end
end
```
`capture_*` returns elements you index with `["action"]` / `["target"]` `[docs]`.

Caveat `[mem]`: with `_later` broadcasts, assertions need the job to run inline —
`perform_enqueued_jobs { ... }` around the block, or `config.active_job.queue_adapter = :test`
with explicit performing. Verify before relying on it.

---

## 9. Rails 8.1 specifics worth knowing

### `params.expect` (8.0+, the current idiom) `[docs]`
Replaces `require(...).permit(...)`. Guaranteed to return a scalar (never an array/hash) when asked
for one, and raises on a malformed structure rather than silently producing a weird shape.

```ruby
params.expect(:id)                                     # scalar
params.expect(user: [:username, :password])            # requires :user root key
params.expect(log_entry: {})                           # permits an entire hash
```
Nested collections use **double brackets** — this is the bit people get wrong `[docs]`:
```ruby
name, emails, friends = params.expect(
  :name,
  emails: [],           # array of permitted scalars
  friends: [[           # array of permitted Parameter hashes  <- note [[ ]]
    :name,
    family: [:name],
    hobbies: []
  ]]
)
```
`accepts_nested_attributes_for` form `[docs]`:
```ruby
params.expect(person: [ :name, addresses_attributes: [[ :id, :kind, :street ]] ])
```

Use `params.expect` throughout Themery; `require/permit` is legacy style now.

### Rails 8.1 major features `[docs]` (guides.rubyonrails.org/8_1_release_notes.html)
- **Active Job Continuations** — `include ActiveJob::Continuable`, break long jobs into resumable
  `step`s with a saved cursor:
  ```ruby
  step :process do |step|
    @import.records.find_each(start: step.cursor) { |r| r.process; step.advance! from: r.id }
  end
  ```
  Directly relevant if Themery does bulk theme imports/screenshot generation.
- **Structured Event Reporting** — `Rails.event.notify("user.signup", user_id: 123)`, with
  `Rails.event.tagged("graphql") { }` and `Rails.event.set_context(request_id: ...)`. Subscribers
  implement `#emit(event)`. Better than the logger for anything you want to post-process.
- **Local CI** — `config/ci.rb` + `bin/ci`, a DSL:
  ```ruby
  CI.run do
    step "Setup", "bin/setup --skip-server"
    step "Style: Ruby", "bin/rubocop"
    step "Security: Gem audit", "bin/bundler-audit"
    step "Security: Importmap vulnerability audit", "bin/importmap audit"
    step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
    step "Tests: Rails", "bin/rails test"
    step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
  end
  ```
  Optional `gh signoff` integration gates PR merges on a passing local run.
- **Markdown rendering** — `format.md { render markdown: @page }` where the object responds to
  `to_markdown`. Nice for Themery theme READMEs / docs pages.
- **Command-line credentials fetching** — `rails credentials:fetch kamal.registry_password`.
  Not needed on Railway, but `rails credentials:fetch` is generally useful for shell scripts.
- **Deprecated associations** — `has_many :posts, deprecated: true`, three reporting modes
  (`:warn`, ...), catches direct calls, `preload`, nested attributes.
- **Registry-free Kamal deployments** — irrelevant here.

### 8.1 notable changes touching this stack
- `config/database.yml` sqlite3: `pool:` → `max_connections:` `[src]` (see §7)
- Authentication generator now writes `app/channels/application_cable/connection.rb` `[src]`
- Redirects are verbose in development for new apps; existing apps opt in with
  `config.action_dispatch.verbose_redirect_logs` (name truncated in the fetched page) `[docs]`
- Action Pack removals: leading-bracket param names no longer stripped; `;` no longer a query-string
  separator; a route can no longer map to multiple paths `[docs]`
- New guide: **"Sign Up and Settings"** (`guides.rubyonrails.org/sign_up_and_settings.html`) — the
  canonical extension path for the auth generator `[docs]`

### Migration/model idioms `[mem]` unless noted
- `bin/rails g migration CreateThemes name:string!:uniq slug:string!` — the `!` (NOT NULL) and `:uniq`
  suffixes are what the auth generator itself uses `[src]`, so they're blessed style.
- `normalizes :slug, with: ->(s) { s.strip.downcase }` on models — the auth generator uses `normalizes`
  for email `[src]`.
- `generates_token_for` for any signed, expiring, self-invalidating token `[docs]`.
- `Current` / `ActiveSupport::CurrentAttributes` for request-scoped state `[src]`.
- `config.active_record.attributes_for_inspect = [ :id ]` is set in production `[src]` — `inspect`
  won't leak attributes in production logs.
- `config.active_record.dump_schema_after_migration = false` in production `[src]`.

---

## Open items to verify before relying on them

1. `_later_to` broadcast method names and the "no `broadcast_remove_later_to`" claim (§5) — `[mem]`.
2. `turbo_refreshes_with method: :morph, scroll: :preserve` layout helper name (§5) — `[mem]`.
3. Whether the generated Dockerfile installs `libvips` in 8.1 (§6) — `[mem]`; check once `rails new` has run.
4. `perform_enqueued_jobs` requirement for asserting `_later` broadcasts (§8) — `[mem]`.
5. Railway volume + Nixpacks vs Dockerfile specifics — not researched here; see the `railway` skill.
6. Signup-time email verification (as opposed to email *change*) — the 8.1 guide covers the change
   flow; the `verified_at` gating variant is extrapolated (§2).
