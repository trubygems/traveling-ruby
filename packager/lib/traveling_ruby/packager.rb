require "digest"
require "fileutils"
require "rubygems/package"

module TravelingRuby
  # Packages an app with a Traveling Ruby runtime for each target. A package is
  # a directory, and a .tar.gz of it:
  #
  #   <name>[-<app version>]-<target>/
  #     <name>             launcher (<name>.bat on Windows)
  #     lib/app/           the app
  #     lib/ruby/          the runtime, with the app's gems installed in it
  #     lib/bundle/config  Bundler settings for the app
  #
  # Gems are installed from their ruby platform .gem files, and native gems
  # get the extensions built for the release, so nothing is compiled.
  class Packager
    PRUNE_DIRS = %w[test tests spec features benchmark doc docs example examples sample].freeze
    PRUNE_EXT_FILES = %w[*.c *.h *.o Makefile extconf.rb mkmf.log].freeze

    attr_reader :name, :targets

    def initialize(app_dir: ".", name: nil, entry: nil, targets: DEFAULT_TARGETS, ruby: nil, revision: nil,
                   source: Release::DEFAULT_SOURCE, out: "pkg", app_version: nil, without: %w[development test],
                   ruby_opts: [], strict: false, prune: true, archive: true, cache_dir: nil, log: $stderr)
      @app_dir = File.expand_path(app_dir)
      raise Error, "#{@app_dir} is not a directory" unless File.directory?(@app_dir)
      @name = name || File.basename(@app_dir)
      @entry = entry || default_entry
      raise Error, "set the entry point, the app's script to run" unless @entry
      raise Error, "#{@entry} not found in #{@app_dir}" unless File.file?(File.join(@app_dir, @entry))
      @targets = Array(targets)
      unknown = @targets - TARGETS
      raise Error, "unknown targets: #{unknown.join(", ")} (known: #{TARGETS.join(", ")})" if unknown.any?
      @ruby = ruby
      @revision = revision
      @source = source
      @out = File.expand_path(out, @app_dir)
      @app_version = app_version
      @without = without
      @ruby_opts = ruby_opts
      @strict = strict
      @prune = prune
      @archive = archive
      @log = log
      @fetcher = cache_dir ? Fetcher.new(cache_dir: cache_dir, log: log) : Fetcher.new(log: log)
      @gem_files = {}
    end

    def release
      @release ||= Release.resolve(fetcher: @fetcher, source: @source, ruby: @ruby, revision: @revision)
    end

    def bundle
      return @bundle if defined?(@bundle)
      @bundle = Bundle.find(@app_dir, without: @without)
    end

    # Builds every target's package; returns the package directories, or the
    # archives when archiving
    def run
      @log.puts "Packaging #{@name} with Traveling Ruby #{release}"
      FileUtils.mkdir_p(@out)
      results = @targets.map { |target| package(target) }
      write_checksums(results) if @archive
      results
    end

    def package_name(target)
      [@name, @app_version, target].compact.join("-")
    end

    def package(target)
      @log.puts "#{target}:"
      dir = File.join(@out, package_name(target))
      lib = File.join(dir, "lib")
      ruby_dir = File.join(lib, "ruby")
      FileUtils.rm_rf(dir)
      FileUtils.mkdir_p(ruby_dir)

      untar(release.runtime(target), ruby_dir)
      copy_app(File.join(lib, "app"))
      if bundle
        install_bundle(target, ruby_dir, lib)
      end
      launcher = File.join(dir, Launcher.file_name(@name, target))
      gemfile = bundle && File.basename(bundle.gemfile)
      File.write(launcher, Launcher.render(target, entry: @entry, gemfile: gemfile, ruby_opts: @ruby_opts))
      File.chmod(0o755, launcher)

      return dir unless @archive
      archive = "#{dir}.tar.gz"
      run!("tar", "-czf", archive, "-C", @out, File.basename(dir))
      @log.puts "  #{archive}"
      archive
    end

    private

    def default_entry
      %W[bin/#{File.basename(@app_dir)} exe/#{File.basename(@app_dir)}].find { |path| File.file?(File.join(@app_dir, path)) }
    end

    def install_bundle(target, ruby_dir, lib)
      gem_home = gem_home(ruby_dir)
      checksums = {}
      installed = []
      bundle.gems(target).each do |gem|
        path = gem_file(gem)
        checksums[gem.full_name] = Digest::SHA256.file(path).hexdigest
        next if installed?(gem_home, gem.full_name)
        install_gem(target, gem_home, path, gem)
        installed << gem.full_name
      end
      prune(gem_home, installed) if @prune

      bundler = Dir.children(File.join(gem_home, "gems")).grep(/\Abundler-/).map { |dir| dir.delete_prefix("bundler-") }
        .max_by { |version| Gem::Version.new(version) }
      lockfile = bundle.packaged_lockfile(checksums: checksums, bundler_version: bundler)
      File.write(File.join(lib, "app", File.basename(bundle.lockfile)), lockfile)
      FileUtils.mkdir_p(File.join(lib, "bundle"))
      File.write(File.join(lib, "bundle", "config"), <<~YAML)
        ---
        BUNDLE_FROZEN: "true"
        BUNDLE_WITHOUT: "#{@without.join(":")}"
      YAML
    end

    # The runtime's gem home, lib/ruby/gems/<Ruby compat version>
    def gem_home(ruby_dir)
      compat_file = File.join(ruby_dir, "info", "RUBY_COMPAT_VERSION")
      compat = File.read(compat_file).strip if File.exist?(compat_file)
      compat ||= Dir.children(File.join(ruby_dir, "lib", "ruby", "gems")).grep(/\A\d+\.\d+\.\d+\z/).max
      File.join(ruby_dir, "lib", "ruby", "gems", compat.to_s)
    end

    def installed?(gem_home, full_name)
      File.exist?(File.join(gem_home, "specifications", "#{full_name}.gemspec")) ||
        File.exist?(File.join(gem_home, "specifications", "default", "#{full_name}.gemspec"))
    end

    # The gem's ruby platform .gem file, downloaded once for every target
    def gem_file(gem)
      @gem_files[gem.full_name] ||= begin
        remote = (gem.remotes.first || "https://rubygems.org/").chomp("/")
        @fetcher.fetch("#{remote}/gems/#{gem.full_name}.gem", sha256: gem.checksum,
                       cache_key: File.join("gems", "#{gem.full_name}.gem"))
      end
    end

    def install_gem(target, gem_home, path, gem)
      package = Gem::Package.new(path)
      spec = package.spec
      package.extract_files(File.join(gem_home, "gems", spec.full_name))
      FileUtils.mkdir_p(File.join(gem_home, "specifications"))
      File.write(File.join(gem_home, "specifications", "#{spec.full_name}.gemspec"), spec.to_ruby_for_cache)
      if spec.extensions.empty?
        @log.puts "  #{spec.full_name}"
      elsif (extension = release.gem_extension(target, gem.name, gem.version))
        untar(extension, File.dirname(gem_home))
        @log.puts "  #{spec.full_name} (native extension from #{release.tag(target)})"
      else
        missing_extension(target, gem)
      end
    end

    def missing_extension(target, gem)
      built = release.gems(target).select { |g| g["name"] == gem.name }.map { |g| g["version"] }
      message =
        if built.any?
          "#{gem.full_name} has a native extension, but #{release.tag(target)} builds #{gem.name} " \
            "#{built.join(", ")}; pin one of those, e.g. gem \"#{gem.name}\", \"#{built.last}\""
        else
          "#{gem.full_name} has a native extension that #{release.tag(target)} does not build; " \
            "it will not load in the package"
        end
      raise Error, message if @strict
      @log.puts "  warning: #{message}"
    end

    def prune(gem_home, full_names)
      full_names.each do |full_name|
        dir = File.join(gem_home, "gems", full_name)
        PRUNE_DIRS.each { |name| FileUtils.rm_rf(File.join(dir, name)) }
        PRUNE_EXT_FILES.each { |pattern| FileUtils.rm_f(Dir.glob(File.join(dir, "ext", "**", pattern))) }
      end
    end

    def copy_app(dest)
      app_files.each do |file|
        target = File.join(dest, file)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(File.join(@app_dir, file), target, preserve: true)
      end
    end

    # Files in a git work tree that git does not ignore, otherwise every file;
    # never the output directory or local bundle state
    def app_files
      files =
        if system("git", "-C", @app_dir, "rev-parse", "--is-inside-work-tree", out: File::NULL, err: File::NULL)
          IO.popen(["git", "-C", @app_dir, "ls-files", "-z", "--cached", "--others", "--exclude-standard"], &:read)
            .split("\0")
        else
          Dir.glob("**/*", File::FNM_DOTMATCH, base: @app_dir)
        end
      excluded = %w[.git .bundle vendor/bundle]
      out = @out.delete_prefix("#{@app_dir}/")
      excluded << out unless out == @out
      files.uniq.reject do |file|
        excluded.any? { |dir| file == dir || file.start_with?("#{dir}/") } ||
          !File.file?(File.join(@app_dir, file))
      end
    end

    def untar(archive, dir)
      run!("tar", "-xzf", archive, "-C", dir)
    end

    def write_checksums(archives)
      lines = archives.map { |path| "#{Digest::SHA256.file(path).hexdigest}  #{File.basename(path)}\n" }
      sums = File.join(@out, "SHA256SUMS")
      existing = File.exist?(sums) ? File.readlines(sums) : []
      names = archives.map { |path| File.basename(path) }
      kept = existing.reject { |line| names.include?(line.split(/ [ *]/, 2).last.to_s.strip) }
      File.write(sums, (kept + lines).sort_by { |line| line.split(/ [ *]/, 2).last }.join)
    end

    def run!(*command)
      system(*command) or raise Error, "#{command.join(" ")} failed"
    end
  end
end
