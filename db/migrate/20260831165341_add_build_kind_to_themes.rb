class AddBuildKindToThemes < ActiveRecord::Migration[8.1]
  def change
    # How much the theme ships, derived mechanically from its manifest:
    # standard (colors + backgrounds), rounded (multiple wallpapers +
    # vendored previews), custom (app configs beyond colors).
    add_column :themes, :build_kind, :string
    add_index :themes, :build_kind
  end
end
