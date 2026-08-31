class MakeStarsAnonymous < ActiveRecord::Migration[8.1]
  def change
    # A star belongs to a voter, not necessarily an account: signed-in users
    # get "user:<id>", visitors get a stable hash of their address. One star
    # per voter per theme.
    add_column :stars, :voter_key, :string
    reversible do |direction|
      direction.up { execute "UPDATE stars SET voter_key = 'user:' || user_id" }
    end
    change_column_null :stars, :voter_key, false
    change_column_null :stars, :user_id, true

    remove_index :stars, column: [ :user_id, :theme_id ], unique: true
    add_index :stars, [ :theme_id, :voter_key ], unique: true
  end
end
