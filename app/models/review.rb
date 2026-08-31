class Review < ApplicationRecord
  belongs_to :user
  belongs_to :theme

  validates :body, presence: true, length: { maximum: 1_000 }
  validates :user_id, uniqueness: { scope: :theme_id }

  scope :newest_first, -> { order(created_at: :desc) }
end
