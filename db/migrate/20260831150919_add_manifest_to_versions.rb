class AddManifestToVersions < ActiveRecord::Migration[8.1]
  def change
    # {"path" => bytes} for every file in the normalized bundle, computed at
    # pipeline time so the review screen diffs versions without unpacking.
    add_column :versions, :manifest, :json, null: false, default: {}
  end
end
