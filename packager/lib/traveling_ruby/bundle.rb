require "bundler"

module TravelingRuby
  # An app's Gemfile and lockfile: which locked gems a target needs, and the
  # lockfile to ship, which locks the ruby platform variant of every gem so it
  # matches what the package installs.
  class Bundle
    GEMFILES = %w[Gemfile gems.rb].freeze

    LockedGem = Struct.new(:name, :version, :remotes, :checksum, keyword_init: true) do
      def full_name
        "#{name}-#{version}"
      end
    end

    attr_reader :gemfile, :lockfile

    def self.find(app_dir, **options)
      gemfile = GEMFILES.map { |file| File.join(app_dir, file) }.find { |path| File.file?(path) }
      gemfile && new(gemfile, **options)
    end

    def initialize(gemfile, without: %w[development test])
      @gemfile = File.expand_path(gemfile)
      @lockfile = @gemfile.end_with?(".rb") ? @gemfile.sub(/\.rb\z/, ".locked") : "#{@gemfile}.lock"
      raise Error, "#{@lockfile} not found; run bundle lock first" unless File.file?(@lockfile)
      @without = without.map(&:to_sym)
      @lock_text = File.read(@lockfile)
      @lock = Bundler::LockfileParser.new(@lock_text)
      @dependencies = evaluate_gemfile
    end

    def app_dir
      File.dirname(@gemfile)
    end

    # The locked gems to install for target, outside the groups left out.
    # Gems from path sources inside the app ship with it and are not included.
    def gems(target)
      by_name = @lock.specs.group_by(&:name)
      queue = @dependencies
        .select { |dep| (dep.groups - @without).any? && platform?(dep.platforms, target) }
        .map(&:name)
      selected = {}
      while (name = queue.shift)
        next if selected.key?(name)
        variants = by_name[name] or next # bundler itself is not locked as a spec
        spec = variants.find { |s| s.platform.to_s == "ruby" } || variants.first
        selected[name] = spec
        queue.concat(spec.dependencies.map(&:name))
      end
      selected.values.filter_map { |spec| locked_gem(spec) }.sort_by(&:name)
    end

    # The lockfile with only ruby platform specs, the given gem checksums and
    # bundler_version as the Bundler it was bundled with
    def packaged_lockfile(checksums:, bundler_version:)
      out = []
      section = nil
      seen = {}
      skipping = false
      @lock_text.each_line do |line|
        if line.match?(/\A\S/)
          section = line.strip
          out << line
          out << "  ruby\n" if section == "PLATFORMS"
          next
        end

        case section
        when "PLATFORMS"
          out << line if line.strip.empty?
        when "BUNDLED WITH"
          out << (bundler_version ? line.sub(/\S+/, bundler_version) : line)
        when "CHECKSUMS"
          name, version = parse_spec_line(line)
          next out << line unless name
          key = "#{name}-#{version}"
          next if seen.key?([section, key])
          seen[[section, key]] = true
          if (sha256 = checksums[key])
            out << "  #{name} (#{version}) sha256=#{sha256}\n"
          elsif line.include?("(#{version})")
            out << line
          else
            out << "  #{name} (#{version})\n"
          end
        when "GEM", "PATH", "GIT"
          if line.start_with?("    ") && !line.start_with?("      ")
            name, version = parse_spec_line(line)
            skipping = seen.key?([section, name, version])
            next if skipping
            seen[[section, name, version]] = true
            out << "    #{name} (#{version})\n"
          elsif line.start_with?("      ")
            out << line unless skipping
          else
            skipping = false
            out << line
          end
        else
          out << line
        end
      end
      out.join
    end

    private

    def evaluate_gemfile
      previous = ENV["BUNDLE_GEMFILE"]
      ENV["BUNDLE_GEMFILE"] = @gemfile
      Dir.chdir(app_dir) { Bundler::Dsl.new.tap { |dsl| dsl.eval_gemfile(@gemfile) }.dependencies }
    ensure
      ENV["BUNDLE_GEMFILE"] = previous
    end

    # Whether a dependency limited to platforms (Bundler's names, such as :ruby,
    # :mri, :windows) is used on target
    def platform?(platforms, target)
      return true if platforms.empty?
      platforms.any? do |platform|
        case platform.to_s
        when /\A(mri|ruby)(_\d+)?\z/ then platform.to_s.start_with?("mri") || !TravelingRuby.windows?(target)
        when /\A(windows|mswin|mswin64|mingw|x64_mingw)(_\d+)?\z/ then TravelingRuby.windows?(target)
        else false
        end
      end
    end

    def locked_gem(spec)
      case (source = spec.source)
      when Bundler::Source::Git
        raise Error, "#{spec.name} comes from git (#{source}); git gems are not supported yet"
      when Bundler::Source::Path
        path = File.expand_path(source.path.to_s, app_dir)
        return nil if path == app_dir || path.start_with?("#{app_dir}/")
        raise Error, "#{spec.name} comes from #{path}, outside the app; path gems must be inside the app"
      when Bundler::Source::Rubygems
        version = spec.version.to_s
        LockedGem.new(
          name: spec.name,
          version: version,
          remotes: source.remotes.map(&:to_s),
          checksum: locked_checksums["#{spec.name}-#{version}"]
        )
      else
        raise Error, "#{spec.name} comes from an unsupported source (#{source})"
      end
    end

    # sha256 checksums of ruby platform gems, from the lockfile's CHECKSUMS
    def locked_checksums
      @locked_checksums ||= begin
        body = @lock_text[/^CHECKSUMS\n((?: .*\n)*)/, 1].to_s
        body.each_line.filter_map do |line|
          match = line.match(/\A\s+(\S+) \(([^)-]+)\) .*sha256=(\h{64})/) or next
          ["#{match[1]}-#{match[2]}", match[3]]
        end.to_h
      end
    end

    # [name, version] from "  name (version[-platform])", or nil
    def parse_spec_line(line)
      match = line.match(/\A\s+(\S+) \(([^)]+)\)/) or return nil
      [match[1], match[2].split("-", 2).first]
    end
  end
end
