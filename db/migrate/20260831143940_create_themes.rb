class CreateThemes < ActiveRecord::Migration[8.1]
  def change
    create_table :themes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :mode
      t.integer :stars_count, null: false, default: 0
      t.integer :installs_count, null: false, default: 0
      t.integer :updates_count, null: false, default: 0
      t.timestamps
    end
    add_index :themes, :name, unique: true
  end
end
