# Development catalog: real omarchy themes pushed through the real pipeline
# (tar → Submission → Validation/Normalization → Approval → Hosted Repo),
# renamed because the vendored names are reserved on purpose.
return unless Rails.env.development?

require "zlib"
require "rubygems/package"

THEMES_DIR = Pathname("#{Dir.home}/.local/share/omarchy/themes")
CONFIG_THEMES_DIR = Pathname("#{Dir.home}/.config/omarchy/themes")

SOURCES = {
  "midnight-mocha" => THEMES_DIR.join("catppuccin"),
  "campfire" => THEMES_DIR.join("gruvbox"),
  "neon-rain" => THEMES_DIR.join("tokyo-night"),
  "briar" => THEMES_DIR.join("rose-pine"),
  "fernshade" => THEMES_DIR.join("everforest"),
  "ukiyo" => THEMES_DIR.join("kanagawa"),
  "paperback" => THEMES_DIR.join("flexoki-light"),
  "oatmilk" => THEMES_DIR.join("catppuccin-latte"),
  "sherbet" => CONFIG_THEMES_DIR.join("sherbet")
}.select { |_name, dir| dir.directory? }

abort "No local omarchy themes found to seed from" if SOURCES.empty?

def archive_of(dir)
  buffer = StringIO.new
  Zlib::GzipWriter.wrap(buffer) do |gz|
    Gem::Package::TarWriter.new(gz) do |tar|
      dir.find do |path|
        next unless path.file? && !path.symlink?
        name = path.relative_path_from(dir).to_s
        tar.add_file_simple(name, 0o644, path.size) { |io| io.write(path.binread) }
      end
    end
  end
  buffer.string
end

author = User.find_or_create_by!(username: "yogan") do |user|
  user.email_address = "author@seed.test"
  user.password = "seedling-password"
  user.email_verified_at = Time.current
end

fans = 3.times.map do |i|
  User.find_or_create_by!(username: "fan-#{i}") do |user|
    user.email_address = "fan#{i}@seed.test"
    user.password = "seedling-password"
    user.email_verified_at = Time.current
  end
end

SOURCES.each do |name, dir|
  next if Theme.exists?(name: name)

  submission = author.submissions.create!(kind: "archive_upload", theme_name: name, changelog: "first release")
  submission.archive.attach(io: StringIO.new(archive_of(dir)), filename: "#{name}.tar.gz", content_type: "application/gzip")
  Publishing::Pipeline.process(submission)
  submission.reload

  if submission.accepted?
    Publishing::Release.approve(submission.version)
    puts "seeded #{name} (#{submission.version.mode})"
  else
    puts "SKIPPED #{name}: #{submission.error_report.join('; ')}"
  end
end

# Social texture so cards and detail pages look inhabited.
Theme.published.find_each.with_index do |theme, index|
  fans.take(1 + index % 3).each { |fan| Star.find_or_create_by!(user: fan, theme:) }
  theme.update_columns(installs_count: [ 214, 96, 58, 341, 27, 130, 12, 74, 190 ][index % 9],
                       updates_count: [ 61, 20, 9, 87, 3, 41, 1, 16, 52 ][index % 9])
end

first = Theme.find_by(name: "sherbet") || Theme.published.first
if first && first.reviews.none?
  first.reviews.create!(user: fans[0], body: "Been dailying this for a month. The selection color is exactly right in bright rooms.")
  first.reviews.create!(user: fans[1], body: "Light themes usually wash out my terminal — this one doesn't. The accent pink is bolder than it looks in the preview.")
end

puts "catalog: #{Theme.published.count} themes"
