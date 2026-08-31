class Theme < ApplicationRecord
  # Names the stock client vendors. A marketplace theme with one of these names
  # would MERGE into the stock theme at install (omarchy-theme-set copies the
  # vendored theme first and overlays), so they are permanently reserved.
  RESERVED_NAMES = %w[
    catppuccin catppuccin-latte ethereal everforest flexoki-light gruvbox
    hackerman kanagawa last-horizon lumon lupine matte-black miasma nord
    osaka-jade retro-82 ristretto rose-pine solitude tokyo-night vantablack white
  ].freeze

  belongs_to :author, class_name: "User", foreign_key: :user_id, inverse_of: :themes
  has_many :versions, dependent: :destroy
  has_many :submissions, dependent: :nullify
  has_many :stars, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :fetch_events, dependent: :delete_all

  normalizes :name, with: ->(n) { canonicalize_name(n) }

  # The client's own rules for an installable directory name: starts with a
  # letter, digit, or underscore; then letters, digits, ., _, +, - (so
  # "c++" and "flexoki_light" are legal names, per the omarchy manual).
  NAME_FORMAT = /\A[a-z0-9_][a-z0-9._+-]*\z/

  validates :name, presence: true, uniqueness: true, length: { maximum: 50 },
    format: { with: NAME_FORMAT, message: "must start with a letter, number, or underscore and use only letters, numbers, ., _, +, -" },
    exclusion: { in: RESERVED_NAMES, message: "is a stock omarchy theme name" }

  has_one :latest_version, -> { approved.order(number: :desc) }, class_name: "Version"

  validates :category, inclusion: { in: PaletteTaxonomy::CATEGORIES }, allow_nil: true
  validates :mood, inclusion: { in: PaletteTaxonomy::MOODS }, allow_nil: true

  scope :published, -> { joins(:versions).where(versions: { state: "approved" }).distinct }
  scope :with_latest_version, -> {
    includes(latest_version: { preview_background_attachment: { blob: { variant_records: { image_attachment: :blob } } } })
  }

  # The stock client derives the install directory from the clone URL
  # (basename, strip omarchy- prefix / -theme suffix, downcase). Because we
  # then SERVE the theme under the stored name, the client applies that
  # transform again on install — so the stored name must be a fixed point of
  # it, or "omarchy-aurora-theme" would be hosted under a URL the client
  # re-derives to "aurora" and uniqueness wouldn't hold on the user's disk.
  def self.canonicalize_name(name)
    name = name.to_s.strip.downcase.delete_suffix(".git")
    name = name.sub(/\Aomarchy-/, "").sub(/-theme\z/, "") while name.match?(/\Aomarchy-|-theme\z/)
    name
  end

  def latest_approved_version
    versions.approved.order(:number).last
  end

  def pending_version
    versions.pending.first
  end

  def published? = versions.approved.exists?

  # "Updated" in the catalog sense: shipped a fresh version recently, as
  # opposed to just having joined.
  def recently_updated?
    latest_version.present? && latest_version.number > 1 &&
      latest_version.approved_at.after?(7.days.ago)
  end
end
