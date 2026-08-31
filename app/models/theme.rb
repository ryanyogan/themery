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

  normalizes :name, with: ->(n) { canonicalize_name(n) }

  validates :name, presence: true, uniqueness: true, length: { maximum: 50 },
    format: { with: /\A[a-z0-9][a-z0-9_-]*\z/, message: "only letters, numbers, hyphens, and underscores" },
    exclusion: { in: RESERVED_NAMES, message: "is a stock omarchy theme name" }

  scope :published, -> { joins(:versions).where(versions: { state: "approved" }).distinct }

  # The stock client derives the install directory from the clone URL with
  # exactly this transform (basename, strip omarchy- prefix / -theme suffix,
  # downcase). Two names that canonicalize identically are the same theme on
  # the user's disk, so this is the identity under which uniqueness holds.
  def self.canonicalize_name(name)
    name.to_s.strip.delete_suffix(".git")
      .sub(/\Aomarchy-/, "").sub(/-theme\z/, "").downcase
  end

  def latest_approved_version
    versions.approved.order(:number).last
  end

  def pending_version
    versions.pending.first
  end

  def published? = versions.approved.exists?
end
