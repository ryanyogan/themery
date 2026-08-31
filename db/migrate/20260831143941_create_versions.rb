class CreateVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :versions do |t|
      t.references :theme, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :state, null: false, default: "pending"
      t.text :changelog
      t.string :mode
      t.json :colors
      t.json :normalization_ledger, null: false, default: {}
      t.text :review_note
      t.datetime :approved_at
      t.string :pack_name
      t.timestamps
    end
    add_index :versions, [ :theme_id, :number ], unique: true
    # The one-pending-Version-per-Theme invariant, enforced where it can't drift.
    add_index :versions, :theme_id, unique: true, where: "state = 'pending'",
      name: "index_versions_on_theme_id_pending"
  end
end
