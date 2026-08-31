class CreateFetchEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :fetch_events do |t|
      t.references :theme, null: false, foreign_key: true
      t.string :pack_name, null: false
      t.string :client_hash, null: false
      t.datetime :created_at, null: false
    end
    add_index :fetch_events, [ :theme_id, :created_at ]
  end
end
