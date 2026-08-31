module Publishing
  # The two human verdicts on a pending Version. Approval is the moment a
  # Version becomes reachable by git clients: the stored normalized bundle is
  # unpacked and committed to the Hosted Repo, and the pack it landed in is
  # recorded for install/update telemetry. Rejection records the verdict and
  # the note; the bundle stays for the audit trail, the repo is untouched.
  class Release
    def self.approve(version, note: nil)
      raise ArgumentError, "only a pending Version can be approved" unless version.pending?

      Dir.mktmpdir("themery-release") do |workspace|
        root = Pathname(workspace)
        unpack(version.bundle, root)

        pack_name = HostedRepo.for(version.theme).publish!(
          root,
          tag: version.tag_name,
          message: release_message(version)
        )

        version.update!(state: "approved", approved_at: Time.current, review_note: note, pack_name:)
        version.theme.update!(mode: version.mode)
      end
      notify_author(version)
      version
    end

    def self.reject(version, note:)
      raise ArgumentError, "only a pending Version can be rejected" unless version.pending?

      version.update!(state: "rejected", review_note: note)
      notify_author(version)
      version
    end

    # The dashboard's live state flip: publishing should feel alive.
    def self.notify_author(version)
      Turbo::StreamsChannel.broadcast_refresh_to([ version.theme.author, :dashboard ])
      return unless version.approved?

      Turbo::StreamsChannel.broadcast_prepend_to(
        "activity", target: "activity_pulse", partial: "activity/item",
        locals: { kind: :published, theme_name: version.theme.name,
                  version_number: version.number, at: version.approved_at }
      )
    end

    def self.release_message(version)
      [ "#{version.tag_name}: #{version.theme.name}", version.changelog.presence ].compact.join("\n\n")
    end

    def self.unpack(bundle, root)
      bundle.open do |file|
        Zlib::GzipReader.wrap(File.open(file.path, "rb")) do |gz|
          Gem::Package::TarReader.new(gz) do |tar|
            tar.each do |entry|
              next unless entry.file?
              target = root.join(entry.full_name)
              target.dirname.mkpath
              target.binwrite(entry.read)
            end
          end
        end
      end
    end
  end
end
