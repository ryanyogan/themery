# One endorsement per voter per theme. A voter is not necessarily an
# account: signed-in users star as "user:<id>", visitors as a stable hash of
# their address — starring should cost one click, not a signup.
class Star < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :theme, counter_cache: true

  validates :voter_key, presence: true, uniqueness: { scope: :theme_id }
end
