module Publishing
  # The mechanical hard-fail checks on a normalized theme tree. Runs after
  # Normalization so a legacy theme's derived colors.toml counts, and so what
  # gets validated is exactly what would ship. Name availability and size
  # caps live in the Pipeline (they need the database and the raw upload);
  # this class judges only the tree.
  class Validation
    Result = Data.define(:errors, :palette) do
      def ok? = errors.empty?
    end

    BACKGROUND_EXTENSIONS = %w[.avif .gif .heic .jpeg .jpg .png .webp].freeze

    def self.check(root)
      new(Pathname(root)).check
    end

    def initialize(root)
      @root = root
      @errors = []
    end

    def check
      palette = check_palette
      check_backgrounds
      Result.new(errors: @errors, palette:)
    end

    private
      def check_palette
        colors = @root.join("colors.toml")
        unless colors.file?
          @errors << "Theme has no colors.toml — every omarchy theme needs one at its root"
          return nil
        end

        result = Publishing::Palette.parse(colors.read)
        @errors << result.error unless result.ok?
        result
      end

      def check_backgrounds
        backgrounds = @root.join("backgrounds")
        candidates = backgrounds.directory? ? backgrounds.children.select(&:file?) : []
        images = candidates.select { |path| real_image?(path) }

        if images.empty?
          @errors << "Theme needs at least one real image in backgrounds/ — " \
            "#{candidates.any? ? 'the files there could not be read as images' : 'the directory is missing or empty'}"
        end
      end

      def real_image?(path)
        return false unless BACKGROUND_EXTENSIONS.include?(path.extname.downcase)

        image = Vips::Image.new_from_file(path.to_s, access: :sequential)
        image.width.positive? && image.height.positive? && image.avg.finite?
      rescue Vips::Error
        false
      end
  end
end
