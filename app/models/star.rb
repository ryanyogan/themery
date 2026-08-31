class Star < ApplicationRecord
  belongs_to :user
  belongs_to :theme, counter_cache: true

  validates :user_id, uniqueness: { scope: :theme_id }
end
