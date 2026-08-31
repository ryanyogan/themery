class CreateSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :submissions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :theme, foreign_key: true
      t.references :version, foreign_key: true
      t.string :kind, null: false
      t.string :theme_name, null: false
      t.string :source_url
      t.string :state, null: false, default: "received"
      t.json :error_report, null: false, default: []
      t.timestamps
    end
  end
end
