module Admin
  class VersionsController < BaseController
    def show
      @version = Version.pending.includes(theme: :author).find(params[:id])
      @theme = @version.theme
      @previous = @theme.latest_approved_version
      @diff = diff_manifests(@previous&.manifest || {}, @version.manifest)
    end

    def approve
      version = Version.pending.find(params[:id])
      version.theme.update!(
        category: params[:category].presence_in(PaletteTaxonomy::CATEGORIES) || version.theme.category,
        mood: params[:mood].presence_in(PaletteTaxonomy::MOODS) || version.theme.mood
      )
      Publishing::Release.approve(version, note: params[:note].presence)
      redirect_to admin_root_path, notice: "Approved #{version.theme.name} v#{version.number} — it's installable now."
    end

    def reject
      version = Version.pending.find(params[:id])
      if params[:note].blank?
        return redirect_to admin_version_path(version), alert: "A rejection needs a note — it should teach, not stonewall."
      end
      Publishing::Release.reject(version, note: params[:note])
      redirect_to admin_root_path, notice: "Rejected #{version.theme.name} v#{version.number} with a note to the author."
    end

    private
      def diff_manifests(old, new)
        {
          added: new.keys - old.keys,
          removed: old.keys - new.keys,
          changed: (new.keys & old.keys).select { |key| new[key] != old[key] }
        }
      end
  end
end
