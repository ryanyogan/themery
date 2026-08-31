class Version < ApplicationRecord
  belongs_to :theme
  # A replaced pending Version is destroyed; the Submission that produced it
  # survives (its error report and audit trail outlive the draft).
  has_many :submissions, dependent: :nullify

  # The normalized theme tree, held here between the pipeline and Approval —
  # it only enters the Hosted Repo when a human approves.
  has_one_attached :bundle

  enum :state, %w[pending approved rejected].index_by(&:itself), default: "pending"

  validates :number, presence: true, uniqueness: { scope: :theme_id }
  validates :changelog, length: { maximum: 2_000 }

  scope :newest_first, -> { order(number: :desc) }

  def self.next_number_for(theme)
    theme.versions.maximum(:number).to_i + 1
  end

  def tag_name = "v#{number}"
end
