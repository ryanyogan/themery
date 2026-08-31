require "zip"
require "rubygems/package"
require "zlib"

module Publishing
  # Extracts an author-supplied archive (.zip or .tar.gz) into a fresh
  # directory. Every member passes through our own checks — nothing is
  # delegated to a shelled tar/unzip — because the archive is the least
  # trusted input in the system:
  #
  #   * path traversal (`../`, absolute paths, NUL) is rejected
  #   * symlinks and hardlinks are rejected (a symlinked unlock.png becomes
  #     a copy of any file the install session can read)
  #   * cumulative extracted size and entry count are capped while streaming,
  #     so a zip bomb dies mid-flight, not after filling the disk
  #   * names that collide case-insensitively or under unicode normalization
  #     are rejected (distinct in the archive, one file on the user's disk)
  #
  # A single wrapping top-level directory (people zip the folder, not its
  # contents) is hoisted so colors.toml lands at the root like a git clone.
  class Extraction
    Result = Data.define(:root, :errors) do
      def ok? = errors.empty?
    end

    MAX_EXTRACTED_BYTES = 150.megabytes
    MAX_ENTRIES = 2_000

    def self.extract(archive_path, into:)
      new(into).extract(archive_path)
    end

    def initialize(dest)
      @dest = Pathname(dest)
      @errors = []
      @written = 0
      @count = 0
      @seen_names = {}
    end

    def extract(archive_path)
      # Format by magic bytes, not filename — the name is user input and
      # intermediate tempfiles don't preserve compound extensions anyway.
      case File.binread(archive_path, 2)
      when "PK".b then extract_zip(archive_path)
      when "\x1f\x8b".b then extract_tar_gz(archive_path)
      else
        @errors << "Unsupported archive format — upload a .zip or .tar.gz"
      end
      hoist_wrapper_directory if @errors.empty?
      Result.new(root: @dest, errors: @errors)
    rescue Zip::Error, Zlib::Error, Gem::Package::Error => e
      Result.new(root: @dest, errors: @errors + [ "Archive is corrupt or unreadable (#{e.class.name.demodulize})" ])
    end

    private
      def extract_zip(path)
        Zip::File.open(path) do |zip|
          zip.each do |entry|
            name = entry.name
            next unless admit?(name, directory: entry.directory?, symlink: entry.symlink?)
            next if entry.directory?

            write(name) do |file|
              entry.get_input_stream do |io|
                stream(io, file, name)
              end
            end
          end
        end
      end

      def extract_tar_gz(path)
        File.open(path, "rb") do |file|
          Zlib::GzipReader.wrap(file) do |gz|
            Gem::Package::TarReader.new(gz) do |tar|
              tar.each do |entry|
                name = entry.full_name.delete_prefix("./")
                next if name.empty?
                link = entry.symlink? || entry.header.typeflag == "1"
                next unless admit?(name, directory: entry.directory?, symlink: link)
                next unless entry.file?

                write(name) { |out| stream(entry, out, name) }
              end
            end
          end
        end
      end

      def admit?(name, directory:, symlink:)
        if symlink
          @errors << "#{name}: links are not allowed in theme archives"
          return false
        end
        if name.include?("\0") || Pathname(name).absolute? || name.split("/").include?("..")
          @errors << "#{name.inspect}: unsafe path in archive"
          return false
        end
        if (@count += 1) > MAX_ENTRIES
          @errors << "Archive has too many entries (limit #{MAX_ENTRIES})"
          return false
        end
        unless directory
          utf8 = name.dup.force_encoding(Encoding::UTF_8)
          unless utf8.valid_encoding?
            @errors << "Archive contains an entry whose name is not valid UTF-8"
            return false
          end
          folded = utf8.unicode_normalize(:nfc).downcase
          if (other = @seen_names[folded])
            @errors << "#{name} collides with #{other} on a case-insensitive filesystem"
            return false
          end
          @seen_names[folded] = name
        end
        true
      end

      def write(name)
        target = @dest.join(name)
        target.dirname.mkpath
        File.open(target, "wb") { |file| yield file }
      end

      def stream(io, out, name)
        while (chunk = io.read(1.megabyte))
          @written += chunk.bytesize
          if @written > MAX_EXTRACTED_BYTES
            @errors << "Archive expands past the #{MAX_EXTRACTED_BYTES / 1.megabyte}MB limit"
            raise Zip::Error, "size cap"
          end
          out.write(chunk)
        end
      end

      def hoist_wrapper_directory
        children = @dest.children
        return unless children.length == 1 && children.first.directory?

        wrapper = children.first
        wrapper.children.each { |child| FileUtils.mv(child, @dest.join(child.basename)) }
        wrapper.rmdir
      end
  end
end
