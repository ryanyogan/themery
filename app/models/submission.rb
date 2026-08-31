# An archive upload or git-URL import entering the publish pipeline.
# Failed Submissions are retained with their error report so authors get
# specific feedback and repeat patterns stay visible to the admin.
class Submission < ApplicationRecord
  belongs_to :user
  belongs_to :theme, optional: true
  belongs_to :version, optional: true

  has_one_attached :archive

  enum :kind, %w[archive_upload git_import].index_by(&:itself)
  enum :state, %w[received failed accepted].index_by(&:itself), default: "received"

  validates :theme_name, presence: true
  validates :source_url, presence: true, if: :git_import?

  scope :newest_first, -> { order(created_at: :desc) }
end
