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

  validates :name, presence: true, uniqueness: true, length: { maximum: 50 },
    format: { with: /\A[a-z0-9][a-z0-9_-]*\z/, message: "only letters, numbers, hyphens, and underscores" },
    exclusion: { in: RESERVED_NAMES, message: "is a stock omarchy theme name" }

  scope :published, -> { joins(:versions).where(versions: { state: "approved" }).distinct }

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
end
