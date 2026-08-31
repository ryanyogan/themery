class AddRegistrationFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin, :boolean, null: false, default: false
    add_column :users, :email_verified_at, :datetime
    add_column :users, :username, :string, null: false
    add_index :users, :username, unique: true
  end
end
