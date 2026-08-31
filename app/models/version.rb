class Version < ApplicationRecord
  belongs_to :theme

  enum :state, %w[pending approved rejected].index_by(&:itself), default: "pending"

  validates :number, presence: true, uniqueness: { scope: :theme_id }
  validates :changelog, length: { maximum: 2_000 }

  scope :newest_first, -> { order(number: :desc) }

  def self.next_number_for(theme)
    theme.versions.maximum(:number).to_i + 1
  end

  def tag_name = "v#{number}"
end
