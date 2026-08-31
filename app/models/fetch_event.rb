# One raw pack fetch from a git client, recorded by the serving middleware.
# Classification happens at recount time: with one pack per approved Version,
# a client that fetched the theme's base pack was installing; one that
# fetched only newer packs was updating. The counters on Theme are recomputed
# from here — this table is the single source of truth for reach metrics.
class FetchEvent < ApplicationRecord
  belongs_to :theme

  def self.recount!(theme)
    base_pack = theme.versions.approved.order(:number).pick(:pack_name)
    return if base_pack.nil?

    packs_by_client = where(theme:).distinct.pluck(:client_hash, :pack_name)
      .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }

    installing, updating = packs_by_client.values.partition { |packs| packs.include?(base_pack) }
    theme.update_columns(installs_count: installing.size, updates_count: updating.size)
  end
end
