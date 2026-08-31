namespace :themery do
  desc "Import the curated omarchy.org extras (db/data/extras_themes.json) through the real pipeline and approve them"
  task import_extras: :environment do
    entries = JSON.parse(Rails.root.join("db/data/extras_themes.json").read)
      .select { |entry| entry["keep"] }

    puts "importing #{entries.size} curated themes…"

    entries.each do |entry|
      name = Theme.canonicalize_name(entry["name"])
      if Theme.exists?(name:)
        puts "  #{name}: already in catalog"
        next
      end

      author = import_author(entry["creator"])
      submission = author.submissions.create!(
        kind: "git_import", theme_name: name, source_url: entry["url"],
        changelog: "Imported from the omarchy.org extras catalog"
      )
      Publishing::Pipeline.process(submission)
      submission.reload

      if submission.accepted?
        Publishing::Release.approve(submission.version)
        puts "  #{name}: published (#{submission.version.mode}, #{submission.theme.category}/#{submission.theme.mood})"
      else
        puts "  #{name}: NOT imported — #{submission.error_report.join('; ')}"
      end
    rescue => e
      puts "  #{name}: ERROR #{e.class}: #{e.message}"
    end

    puts "catalog now holds #{Theme.published.count} themes"
  end

  def import_author(creator)
    handle = creator.to_s.downcase.gsub(/[^a-z0-9-]+/, "-").gsub(/\A-+|-+\z/, "")
    handle = "community" if handle.blank?
    User.find_or_create_by!(username: handle) do |user|
      user.email_address = "#{handle}@import.invalid"
      user.password = SecureRandom.base58(24)
      user.email_verified_at = Time.current
    end
  end
end
