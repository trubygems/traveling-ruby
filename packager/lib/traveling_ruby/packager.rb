require "digest"
require "fileutils"
require "pathname"
require "rubygems/package"

module TravelingRuby
  # Packages an app with a Traveling Ruby runtime for each target. A package is
  # a directory, and a .tar.gz of it:
  #
  #   <name>[-<app version>]-<target>/
  #     <bin>              a launcher per program (<bin>.bat on Windows)
  #     lib/app/           the app
  #     lib/ruby/          the runtime, with the app's gems installed in it
  #     lib/bundle/config  Bundler settings for the app
  #
  # Gems are installed from their ruby platform .gem files, and native gems
  # get the extensions built for the release, so nothing is compiled.
  class Packager
    PRUNE_DIRS = %w[test tests spec features benchmark doc docs example examples sample].freeze
    PRUNE_EXT_FILES = %w[*.c *.h *.o Makefile extconf.rb mkmf.log].freeze
    RUNTIMES = %w[slim full].freeze

    # A program to make a launcher for: a script in the app, or a gem's executable
    Program = Struct.new(:name, :script, :spec, keyword_init: true) do
      def gem?
        !spec.nil?
      end

      def to_s
        gem? ? "#{spec.name}'s #{name}" : script
      end
    end

    # How a locked gem with a native extension fares on each target
    Extension = Struct.new(:gem, :built, :runtime, :missing, :versions, keyword_init: true) do
      def ok?
        missing.empty?
      end
    end

    attr_reader :name, :targets, :ui

    def initialize(app_dir: ".", name: nil, entry: nil, bins: nil, gem_bins: nil, targets: DEFAULT_TARGETS,
                   ruby: nil, revision: nil, runtime: "slim", source: Release::DEFAULT_SOURCE, out: "pkg",
                   app_version: nil, without: %w[development test], ruby_opts: [], keep: [], prune: true,
                   archive: true, allow_missing_extensions: false, cache_dir: nil, ui: UI.new)
      @app_dir = File.expand_path(app_dir)
      raise Error, "#{@app_dir} is not a directory" unless File.directory?(@app_dir)
      @name = name || File.basename(@app_dir)
      @bins = bins&.to_h || (entry ? {@name => entry} : {})
      @gem_bins = gem_bins
      @targets = Array(targets)
      raise Error, "no targets given" if @targets.empty?
      unknown = @targets - TARGETS
      raise Error, "unknown targets: #{unknown.join(", ")} (known: #{TARGETS.join(", ")})" if unknown.any?
      @runtime = runtime.to_s
      raise Error, "runtime must be one of #{RUNTIMES.join(", ")}, not #{@runtime}" unless RUNTIMES.include?(@runtime)
      @ruby = ruby
      @revision = revision
      @source = source
      @out = File.expand_path(out, @app_dir)
      @app_version = app_version
      @without = without
      @ruby_opts = ruby_opts
      @keep = keep
      @prune = prune
      @archive = archive
      @allow_missing_extensions = allow_missing_extensions
      @ui = ui
      @fetcher = cache_dir ? Fetcher.new(cache_dir: cache_dir, ui: ui) : Fetcher.new(ui: ui)
      @gem_files = {}
      @specs = {}
    end

    def release
      @release ||= Release.resolve(fetcher: @fetcher, source: @source, ruby: @ruby, revision: @revision)
    end

    def bundle
      return @bundle if defined?(@bundle)
      @bundle = Bundle.find(@app_dir, without: @without)
    end

    def full?
      @runtime == "full"
    end

    def label
      [@name, @app_version].compact.join(" ")
    end

    # Builds every target's package; returns the package directories, or the
    # archives when archiving
    def run
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @ui.title "Packaging #{label} with Ruby #{release.ruby} (Traveling Ruby #{release}#{", full runtime" if full?})"
      programs
      verify_extensions
      FileUtils.mkdir_p(@out)
      results = @targets.map { |target| package(target) }
      write_checksums(results) if @archive
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      @ui.say
      @ui.say "#{@ui.paint("Done", :green, :bold)} in #{UI.duration(elapsed)}. " \
              "#{programs.size == 1 ? "Launcher" : "Launchers"}: #{programs.map(&:name).join(", ")}"
      results
    end

    # Checks that the app can be packaged for every target without building
    # anything: its launchers resolve, and every native gem has an extension.
    # Prints a report; returns whether all is well.
    def check
      @ui.title "Checking #{label} with Ruby #{release.ruby} (Traveling Ruby #{release}) for #{@targets.join(", ")}"
      ok = true

      @ui.say
      @ui.say "Launchers"
      begin
        width = programs.map { |program| program.name.size }.max
        programs.each { |program| @ui.done(program.name.ljust(width), program.to_s) }
      rescue Error => e
        @ui.failed e.message
        ok = false
      end

      @ui.say
      @ui.say "Gems"
      if bundle.nil?
        @ui.done "no Gemfile; the app uses only Ruby's own gems"
        return ok
      end
      gems = @targets.flat_map { |target| bundle.gems(target) }.uniq(&:full_name)
      @ui.done "#{gems.size} locked for the ruby platform"
      report = extensions
      if report.empty?
        @ui.done "none have native extensions"
      else
        width = report.map { |extension| extension.gem.full_name.size }.max
        report.each do |extension|
          name = extension.gem.full_name.ljust(width)
          if extension.ok?
            where = [("built for #{targets_text(extension.built)}" if extension.built.any?),
                     ("comes with Ruby on #{targets_text(extension.runtime)}" if extension.runtime.any?)].compact
            @ui.done name, where.join("; ")
          else
            ok = false
            @ui.failed name, "no extension built for #{targets_text(extension.missing)}"
            @ui.hint extension_hint(extension)
          end
        end
      end
      @ui.say
      @ui.say(ok ? @ui.paint("Ready to package.", :green, :bold) : @ui.paint("Not ready to package.", :red, :bold))
      ok
    end

    # Native gems' extensions across the targets
    def extensions
      return [] unless bundle
      @extensions ||= begin
        by_gem = {}
        @targets.each do |target|
          bundle.gems(target).each do |gem|
            next if spec(gem).extensions.empty?
            extension = by_gem[gem.full_name] ||= Extension.new(gem: gem, built: [], runtime: [], missing: [], versions: [])
            if release.built_versions(target, gem.name).include?(gem.version)
              extension.built << target
            elsif release.runtime_gems(target, full: full?).include?(gem.full_name)
              extension.runtime << target
            else
              extension.missing << target
              extension.versions |= release.built_versions(target, gem.name)
            end
          end
        end
        by_gem.values.sort_by { |extension| extension.gem.name }
      end
    end

    # The programs to make launchers for, from bins; or, with none, the gem's
    # executables when packaging a gem, or bin/NAME or exe/NAME
    def programs
      @programs ||= begin
        bins = @bins
        bins = gem_executables(@gem_bins).to_h { |exe| [exe, nil] } if bins.empty? && @gem_bins
        if bins.empty?
          entry = default_entry or raise Error,
            "nothing to launch: add bin/#{@name} or exe/#{@name}, or name the programs with --bin or bin: in truby.yml"
          bins = {@name => entry}
        end
        bins.map { |name, script| program(name, script) }
      end
    end

    def package_name(target)
      [@name, @app_version, target].compact.join("-")
    end

    def package(target)
      dir = File.join(@out, package_name(target))
      lib = File.join(dir, "lib")
      ruby_dir = File.join(lib, "ruby")
      FileUtils.rm_rf(dir)
      FileUtils.mkdir_p(ruby_dir)

      untar(release.runtime(target, full: full?), ruby_dir)
      copy_app(File.join(lib, "app"))
      gems = bundle ? install_bundle(target, ruby_dir, lib) : []
      gemfile = bundle && File.basename(bundle.gemfile)
      programs.each do |program|
        launcher = File.join(dir, Launcher.file_name(program.name, target))
        File.write(launcher, Launcher.render(target, script: script_path(program, ruby_dir, lib), gemfile: gemfile,
                                                     ruby_opts: @ruby_opts))
        File.chmod(0o755, launcher)
      end

      native = gems.count { |gem| !spec(gem).extensions.empty? }
      summary = "#{gems.size} #{gems.size == 1 ? "gem" : "gems"}#{", #{native} native" if native.positive?}"
      result = dir
      if @archive
        result = "#{dir}.tar.gz"
        run!("tar", "-czf", result, "-C", @out, File.basename(dir))
      end
      @ui.done target.ljust(@targets.map(&:size).max), "#{summary.ljust(18)} #{display_path(result)}" \
                                                     "#{"  #{UI.size(File.size(result))}" if @archive}"
      result
    end

    private

    def default_entry
      %W[bin/#{@name} exe/#{@name} bin/#{File.basename(@app_dir)} exe/#{File.basename(@app_dir)}]
        .find { |path| File.file?(File.join(@app_dir, path)) }
    end

    def program(name, script)
      if script
        raise Error, "#{name}: #{script} not found in #{@app_dir}" unless File.file?(File.join(@app_dir, script))
        return Program.new(name: name, script: script)
      end
      script = %W[bin/#{name} exe/#{name} #{name}.rb #{name}].find { |path| File.file?(File.join(@app_dir, path)) }
      return Program.new(name: name, script: script) if script
      spec = locked_specs.find { |s| s.executables.include?(name) } or raise Error,
        "#{name}: no bin/#{name}, exe/#{name} or #{name}.rb in the app, and no locked gem has a #{name} executable; " \
        "give its script, as in --bin #{name}=path/to/script"
      Program.new(name: name, script: name, spec: spec)
    end

    def gem_executables(gem_name)
      spec = locked_specs.find { |s| s.name == gem_name } or raise Error, "#{gem_name} is not in the lockfile"
      raise Error, "#{gem_name} has no executables; name the programs with --bin" if spec.executables.empty?
      spec.executables
    end

    def locked_specs
      return [] unless bundle
      @targets.flat_map { |target| bundle.gems(target) }.uniq(&:full_name).map { |gem| spec(gem) }
    end

    # The script a launcher runs, relative to lib/
    def script_path(program, ruby_dir, lib)
      return "app/#{program.script}" unless program.gem?
      spec = program.spec
      path = File.join(gem_home(ruby_dir), "gems", spec.full_name, spec.bindir, program.name)
      Pathname(path).relative_path_from(Pathname(lib)).to_s
    end

    def verify_extensions
      missing = extensions.reject(&:ok?)
      return if missing.empty?
      missing.each do |extension|
        @ui.send(@allow_missing_extensions ? :warn : :failed,
                 "#{extension.gem.full_name} has a native extension that #{release} does not build for " \
                 "#{targets_text(extension.missing)}")
        @ui.hint extension_hint(extension)
      end
      return if @allow_missing_extensions
      raise Error, "#{missing.size} native #{missing.size == 1 ? "gem has" : "gems have"} no extension for some " \
                   "targets; pin a built version, or pass --allow-missing-extensions to package without them"
    end

    def extension_hint(extension)
      gem = extension.gem
      if extension.versions.any?
        latest = extension.versions.max_by { |version| Gem::Version.new(version) }
        "#{release} builds #{gem.name} #{extension.versions.join(", ")}: pin it with gem \"#{gem.name}\", \"#{latest}\""
      else
        "#{release} does not build #{gem.name}; ask for it at https://github.com/trubygems/traveling-ruby/issues"
      end
    end

    def targets_text(list)
      list.sort == @targets.sort && list.size > 1 ? "all targets" : list.join(", ")
    end

    def display_path(path)
      relative = Pathname(path).relative_path_from(Pathname(Dir.pwd)).to_s
      relative.start_with?("..") ? path : relative
    rescue ArgumentError
      path
    end

    # Installs the target's gems; returns them
    def install_bundle(target, ruby_dir, lib)
      gem_home = gem_home(ruby_dir)
      checksums = {}
      installed = []
      gems = bundle.gems(target)
      gems.each do |gem|
        path = gem_file(gem)
        checksums[gem.full_name] = Digest::SHA256.file(path).hexdigest
        if installed?(gem_home, gem.full_name)
          @ui.detail "#{gem.full_name} (comes with Ruby)"
          next
        end
        install_gem(target, gem_home, path, gem)
        installed << gem
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
      gems
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

    def spec(gem)
      @specs[gem.full_name] ||= Gem::Package.new(gem_file(gem)).spec
    end

    def install_gem(target, gem_home, path, gem)
      spec = spec(gem)
      Gem::Package.new(path).extract_files(File.join(gem_home, "gems", spec.full_name))
      FileUtils.mkdir_p(File.join(gem_home, "specifications"))
      File.write(File.join(gem_home, "specifications", "#{spec.full_name}.gemspec"), spec.to_ruby_for_cache)
      if spec.extensions.empty?
        @ui.detail spec.full_name
      elsif (extension = release.gem_extension(target, gem.name, gem.version))
        untar(extension, File.dirname(gem_home))
        @ui.detail "#{spec.full_name} (native extension from #{release.tag(target)})"
      else
        @ui.detail "#{spec.full_name} (no native extension)"
      end
    end

    # Removes tests, docs and extension sources from the installed gems, except
    # what keep names: a gem, or a path in one (pact_broker/public)
    def prune(gem_home, gems)
      gems.each do |gem|
        next if @keep.include?(gem.name)
        dir = File.join(gem_home, "gems", gem.full_name)
        kept = @keep.filter_map { |path| path.delete_prefix("#{gem.name}/") if path.start_with?("#{gem.name}/") }
        prunable = PRUNE_DIRS.reject { |name| kept.any? { |path| path == name || path.start_with?("#{name}/") } }
        prunable.each { |name| FileUtils.rm_rf(File.join(dir, name)) }
        next if kept.any? { |path| path == "ext" || path.start_with?("ext/") }
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
