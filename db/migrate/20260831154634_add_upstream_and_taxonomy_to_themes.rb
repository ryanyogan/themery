class AddUpstreamAndTaxonomyToThemes < ActiveRecord::Migration[8.1]
  def change
    change_table :themes do |t|
      # Canonical upstream repo (git-only publishing) and the last HEAD sha
      # the hourly sync saw, so unchanged upstreams cost one ls-remote.
      t.string :source_url
      t.string :upstream_commit
      # Palette family and mood, auto-derived at pipeline time and
      # overridable at review. Both filterable in the gallery.
      t.string :category
      t.string :mood
    end
    add_index :themes, :category
    add_index :themes, :mood
  end
end
