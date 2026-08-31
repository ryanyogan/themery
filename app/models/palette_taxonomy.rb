# Derives a theme's palette family and mood from its parsed colors — every
# theme gets a defensible default at pipeline time, and the admin can
# overrule it at review. Pure function of the palette; no I/O.
class PaletteTaxonomy
  CATEGORIES = %w[warm cool earthy neon pastel monochrome].freeze
  MOODS = %w[calm cozy vibrant moody crisp dreamy].freeze

  CHROMATIC_KEYS = %w[accent red orange yellow green cyan blue magenta].freeze

  Result = Data.define(:category, :mood)

  def self.classify(colors, mode)
    new(colors, mode).classify
  end

  def initialize(colors, mode)
    @colors = colors
    @dark = mode != "light"
  end

  def classify
    Result.new(category:, mood:)
  end

  private
    def category
      return "monochrome" if saturation < 0.16
      return "neon" if @dark && saturation > 0.62
      return "pastel" if !@dark && lightness > 0.62 && saturation < 0.62
      return "earthy" if earthy_hue? && saturation < 0.55
      warm_hue? ? "warm" : "cool"
    end

    def mood
      return "moody" if @dark && saturation < 0.35
      return "vibrant" if saturation > 0.6
      return "cozy" if @dark && warm_hue?
      return "calm" if !@dark && saturation < 0.45
      @dark ? "dreamy" : "crisp"
    end

    def chroma
      @chroma ||= CHROMATIC_KEYS.filter_map { |key| hsl(@colors[key]) }
    end

    def saturation = average(chroma.map { |color| color[1] })
    def lightness = average(chroma.map { |color| color[2] })

    def accent_hue
      (hsl(@colors["accent"]) || hsl(@colors["blue"]) || [ 220 ]).first
    end

    def warm_hue? = accent_hue < 70 || accent_hue >= 320
    def earthy_hue? = accent_hue.between?(20, 160)

    def average(values)
      values.empty? ? 0.0 : values.sum / values.size
    end

    def hsl(value)
      return nil unless value.to_s.match?(ThemesHelper::HEX)

      r, g, b = value.delete_prefix("#").scan(/\h\h/).first(3).map { |c| c.hex / 255.0 }
      max, min = [ r, g, b ].max, [ r, g, b ].min
      l = (max + min) / 2.0
      return [ 0.0, 0.0, l ] if max == min

      d = max - min
      s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min)
      h = case max
      when r then ((g - b) / d) % 6
      when g then (b - r) / d + 2
      else (r - g) / d + 4
      end
      [ h * 60.0, s, l ]
    end
end
