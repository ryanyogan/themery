class Version < ApplicationRecord
  belongs_to :theme
  # A replaced pending Version is destroyed; the Submission that produced it
  # survives (its error report and audit trail outlive the draft).
  has_many :submissions, dependent: :nullify

  # The normalized theme tree, held here between the pipeline and Approval —
  # it only enters the Hosted Repo when a human approves.
  has_one_attached :bundle

  # The theme's first background, extracted at pipeline time so previews and
  # cards never pull multi-megabyte images out of git. Variants are the only
  # sizes pages ever render.
  has_one_attached :preview_background do |attachable|
    attachable.variant :card, resize_to_fill: [ 640, 400 ], preprocessed: true
    attachable.variant :hero, resize_to_fill: [ 1440, 900 ]
  end

  # Every background the theme ships, for the detail page's wallpaper strip.
  has_many_attached :backgrounds do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 320, 200 ]
    attachable.variant :hero, resize_to_fill: [ 1440, 900 ]
  end

  # The theme's own preview.png screenshots (the spec's Screenshot
  # primitive): real desktop captures the author vendors in the repo.
  # When present, these lead — the Generated Preview becomes the fallback.
  has_many_attached :screenshots do |attachable|
    attachable.variant :card, resize_to_fill: [ 640, 400 ], preprocessed: true
    attachable.variant :thumb, resize_to_fill: [ 320, 200 ]
    attachable.variant :hero, resize_to_limit: [ 1600, 1000 ]
  end

  # The share card, rendered once at Approval (see Publishing::Release).
  has_one_attached :og_card

  enum :state, %w[pending approved rejected].index_by(&:itself), default: "pending"

  validates :number, presence: true, uniqueness: { scope: :theme_id }
  validates :changelog, length: { maximum: 2_000 }

  scope :newest_first, -> { order(number: :desc) }

  def self.next_number_for(theme)
    theme.versions.maximum(:number).to_i + 1
  end

  def tag_name = "v#{number}"
end
