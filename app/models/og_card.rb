require "base64"
require "open3"

# The share card: what a theme link unfurls into on Discord/X. Rendered as
# SVG from the same palette the preview uses — theme background across the
# canvas, a scrim in the theme's own background color, name and palette
# chips — then rasterized with rsvg-convert. (Not vips svgload: Active
# Storage blocks vips's untrusted loaders app-wide, and that fence is worth
# keeping — this SVG is self-authored, so a dedicated subprocess is the
# clean carve-out.) Generated once at Approval and attached to the Version;
# never rendered per-request.
class OgCard
  class RenderFailed < StandardError; end
  WIDTH = 1200
  HEIGHT = 630
  CHIP_KEYS = %w[red orange yellow green cyan blue magenta foreground].freeze
  FONT = "JetBrains Mono, DejaVu Sans Mono, monospace"

  def self.png_for(version)
    new(version).png
  end

  def initialize(version)
    @version = version
    @colors = version.colors
  end

  def png
    stdout, stderr, status = Open3.capture3("rsvg-convert", "-f", "png", stdin_data: svg, binmode: true)
    raise RenderFailed, stderr.lines.first.to_s.strip unless status.success? && stdout.present?
    stdout
  end

  def svg
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{WIDTH}" height="#{HEIGHT}">
        <rect width="#{WIDTH}" height="#{HEIGHT}" fill="#{color('background', '#1e1e2e')}"/>
        #{background_image}
        <rect width="#{WIDTH}" height="#{HEIGHT}" fill="url(#scrim)"/>
        <defs>
          <linearGradient id="scrim" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0.30" stop-color="#{color('background', '#1e1e2e')}" stop-opacity="0"/>
            <stop offset="0.62" stop-color="#{color('background', '#1e1e2e')}" stop-opacity="0.72"/>
            <stop offset="1" stop-color="#{color('background', '#1e1e2e')}" stop-opacity="0.97"/>
          </linearGradient>
        </defs>
        <text x="64" y="448" font-family="#{FONT}" font-size="26" fill="#{color('accent', '#89b4fa')}">❯ omarchy-theme-install</text>
        <text x="64" y="516" font-family="#{FONT}" font-size="72" font-weight="700" fill="#{color('foreground', '#cdd6f4')}">#{name}</text>
        #{chips}
        <text x="#{WIDTH - 64}" y="516" text-anchor="end" font-family="#{FONT}" font-size="28" fill="#{color('foreground', '#cdd6f4')}">#{stats}</text>
        <text x="#{WIDTH - 64}" y="574" text-anchor="end" font-family="#{FONT}" font-size="22" fill="#{color('muted', '#9399b2')}">themery · #{@version.mode} theme</text>
      </svg>
    SVG
  end

  private
    def name = ERB::Util.html_escape(@version.theme.name)

    def stats = "★ #{@version.theme.stars_count}  ↓ #{@version.theme.installs_count}"

    def color(key, fallback)
      value = @colors[key].to_s
      value.match?(ThemesHelper::HEX) ? value : fallback
    end

    def chips
      CHIP_KEYS.filter_map { |key| @colors[key] if @colors[key].to_s.match?(ThemesHelper::HEX) }
        .each_with_index.map { |value, index|
          %(<rect x="#{64 + index * 54}" y="548" width="40" height="40" rx="8" fill="#{value}"/>)
        }.join
    end

    def background_image
      return "" unless @version.preview_background.attached?

      data = thumbnail_data
      return "" if data.nil?

      %(<image href="data:image/png;base64,#{Base64.strict_encode64(data)}" width="#{WIDTH}" height="#{HEIGHT}" preserveAspectRatio="xMidYMid slice"/>)
    rescue Vips::Error, ActiveStorage::Error
      ""
    end

    def thumbnail_data
      @version.preview_background.open do |file|
        image = Vips::Image.thumbnail(file.path, WIDTH, height: HEIGHT, crop: :centre)
        return image.write_to_buffer(".png")
      end
    end
end
