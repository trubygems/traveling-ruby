require "optparse"
require "bundler"
require "open3"
require "tmpdir"

module TravelingRuby
  # truby (also installed as traveling-ruby): the command line
  class CLI
    PROGRAM = "truby".freeze

    # Raised once --help has printed a command's help
    class HelpShown < StandardError; end

    def initialize(out: $stdout, err: $stderr)
      @out = out
      @err = err
      @ui = UI.new(err)
    end

    def run(argv)
      argv = argv.dup
      case (command = argv.shift)
      when "package" then package(argv)
      when "check" then check(argv)
      when "gem" then package_gem(argv)
      when "init" then init(argv)
      when "targets" then @out.puts(TARGETS) || 0
      when "version", "--version" then @out.puts("#{PROGRAM} #{VERSION}") || 0
      when nil, "help", "--help", "-h" then @out.puts(usage) || 0
      else
        @err.puts "#{PROGRAM}: unknown command #{command.inspect}\n\n#{usage}"
        1
      end
    rescue HelpShown
      0
    rescue Error, OptionParser::ParseError => e
      @err.puts "#{@ui.paint("#{PROGRAM}:", :red, :bold)} #{e.message}"
      1
    rescue Interrupt
      @err.puts
      130
    end

    private

    def usage
      <<~USAGE
        #{PROGRAM} packages Ruby apps with Traveling Ruby, a portable Ruby, so they run
        on Linux, macOS and Windows without Ruby installed.

        Usage: #{PROGRAM} <command> [options]

        Commands:
          package [APP_DIR]    Package an app for each target
          check [APP_DIR]      Check an app is ready to package, without building it
          gem NAME[:VERSION]   Package a gem's executables, such as rubocop
          init [APP_DIR]       Write a truby.yml with the app's settings
          targets              List the targets
          version              Show the version

        Settings come from truby.yml in the app, and options win over it.
        Run #{PROGRAM} <command> --help for a command's options.
      USAGE
    end

    def package(argv)
      options = {}
      args = parser(options, "package [options] [APP_DIR]",
                    "Packages the app in APP_DIR (default .) for each target, with its Gemfile.lock's gems.").parse(argv)
      app_dir = app_dir(args)
      print_paths(packager(app_dir, options).run)
      0
    end

    def check(argv)
      options = {}
      args = parser(options, "check [options] [APP_DIR]",
                    "Checks the app in APP_DIR (default .) is ready to package: its launchers resolve, its gems " \
                    "are locked for the ruby platform and every native gem has an extension built for each target.")
        .parse(argv)
      packager(app_dir(args), options).check ? 0 : 1
    end

    def package_gem(argv)
      options = {}
      args = parser(options, "gem [options] NAME[:VERSION]",
                    "Packages a gem from rubygems.org with a launcher for each of its executables " \
                    "(or the ones given with --bin), into ./pkg.", app: false).parse(argv)
      raise OptionParser::InvalidArgument, "give one gem, as in #{PROGRAM} gem rubocop:1.70.0" unless args.size == 1
      gem_name, version = args.first.split(/[:@]/, 2)

      Dir.mktmpdir("truby-gem-") do |dir|
        File.write(File.join(dir, "Gemfile"), <<~RUBY)
          source "https://rubygems.org"
          gem #{gem_name.inspect}#{", #{version.inspect}" if version}
        RUBY
        @ui.say @ui.paint("  Resolving #{gem_name}#{" #{version}" if version}", :dim)
        output, status = Bundler.with_unbundled_env do
          Open3.capture2e("bundle", "lock", "--add-platform", "ruby", chdir: dir)
        end
        raise Error, "could not resolve #{args.first}:\n#{output}" unless status.success?
        locked = Bundler::LockfileParser.new(File.read(File.join(dir, "Gemfile.lock"))).specs
          .find { |spec| spec.name == gem_name }
        options[:out] = File.expand_path(options[:out] || "pkg")
        options[:name] ||= gem_name
        packager = Packager.new(app_dir: dir, app_version: locked.version.to_s, gem_bins: gem_name, ui: @ui, **options)
        print_paths(packager.run)
      end
      0
    end

    def init(argv)
      force = false
      args = OptionParser.new do |o|
        o.banner = "Usage: #{PROGRAM} init [options] [APP_DIR]"
        o.separator ""
        o.separator "Writes APP_DIR/truby.yml (default ./truby.yml) with the app's name and programs."
        o.separator ""
        o.on("-f", "--force", "Overwrite an existing truby.yml") { force = true }
        o.on("-h", "--help", "Show this help") do
          @out.puts o
          raise HelpShown
        end
      end.parse(argv)
      app_dir = File.expand_path(app_dir(args))
      path = File.join(app_dir, "truby.yml")
      existing = Config.find(app_dir)
      raise Error, "#{existing} already exists; pass --force to overwrite it" if existing && !force

      name = File.basename(app_dir)
      bins = (Dir.glob("{bin,exe}/*", base: app_dir) - %w[bin/setup bin/console bin/bundle bin/rake bin/rails])
        .select { |file| File.file?(File.join(app_dir, file)) }
        .sort
      version_file = File.join(app_dir, "VERSION")
      lines = ["# Packaging settings for #{PROGRAM} (gem install traveling-ruby)", "name: #{name}"]
      lines << "version: #{File.read(version_file).strip}" if File.file?(version_file)
      lines << "targets: [#{DEFAULT_TARGETS.join(", ")}]"
      if bins.empty?
        lines << "# bin:            # a launcher per program: name: script in the app"
        lines << "#   #{name}: #{name}.rb"
      else
        lines << "bin:"
        bins.each { |file| lines << "  #{File.basename(file)}: #{file}" }
      end
      lines << "# ruby: 3.4.12          # default: the latest release's Ruby"
      lines << "# ruby_opts: [-EUTF-8]"
      lines << "# keep: [some_gem/docs]   # gem files that pruning would remove"
      File.write(path, lines.join("\n") + "\n")
      @ui.done "wrote #{path}"
      @ui.hint "next: #{PROGRAM} check, then #{PROGRAM} package"
      0
    end

    # Package paths for scripts, when stdout is piped; a terminal already has
    # them in the report
    def print_paths(paths)
      paths.each { |path| @out.puts path } unless @out.respond_to?(:tty?) && @out.tty?
    end

    def app_dir(args)
      raise OptionParser::InvalidArgument, "one app directory at most" if args.size > 1
      args.first || "."
    end

    # The app's truby.yml, with the command line's options over it
    def packager(app_dir, options)
      settings = Config.load(app_dir).merge(options)
      Packager.new(app_dir: app_dir, ui: @ui, **settings)
    end

    def parser(options, banner, description, app: true)
      OptionParser.new do |o|
        o.banner = "Usage: #{PROGRAM} #{banner}"
        o.separator ""
        o.separator description
        o.separator ""
        if app
          o.on("--name NAME", "Package name (default: the app directory's name)") { |v| options[:name] = v }
          o.on("--app-version VERSION", "Version to put in package names") { |v| options[:app_version] = v }
        end
        o.on("--bin NAME[=SCRIPT]", "A launcher: NAME runs SCRIPT in the app, or else bin/NAME, exe/NAME,",
             "NAME.rb or a gem's NAME executable (repeatable; default: bin/NAME or exe/NAME)") do |v|
          name, script = Config.parse_bin(v)
          (options[:bins] ||= {})[name] = script
        end
        o.on("--targets LIST", Array, "Comma-separated targets (default: #{DEFAULT_TARGETS.join(",")})") { |v| options[:targets] = v }
        o.on("--ruby VERSION", "Ruby version (default: the latest release's)") { |v| options[:ruby] = v }
        o.on("--revision N", "Release revision (default: the newest for the Ruby version)") { |v| options[:revision] = v }
        o.on("--full", "Use the full runtime, with Ruby's headers and static libraries") { options[:runtime] = "full" }
        o.on("--out DIR", "Output directory (default: pkg)") { |v| options[:out] = v }
        o.on("--without GROUPS", Array, "Gem groups to leave out (default: development,test)") { |v| options[:without] = v }
        o.on("--ruby-opt OPT", "Option for ruby in the launchers, e.g. -EUTF-8 (repeatable)") { |v| (options[:ruby_opts] ||= []) << v }
        o.on("--keep GEM[/PATH]", "Keep a gem's files that pruning would remove (repeatable)") { |v| (options[:keep] ||= []) << v }
        o.on("--allow-missing-extensions", "Package native gems with no extension built, rather than fail") do
          options[:allow_missing_extensions] = true
        end
        o.on("--[no-]prune", "Remove gems' tests, docs and extension sources (default: on)") { |v| options[:prune] = v }
        o.on("--[no-]archive", "Make a .tar.gz of each package and SHA256SUMS (default: on)") { |v| options[:archive] = v }
        o.on("--source URL_OR_DIR", "GitHub repository or directory of releases (default: #{Release::DEFAULT_SOURCE})") { |v| options[:source] = v }
        o.on("--cache DIR", "Download cache (default: #{Fetcher.default_cache_dir})") { |v| options[:cache_dir] = v }
        o.on("--entry PATH", "Same as --bin NAME=PATH, for the package's name") { |v| options[:entry] = v } if app
        o.on("-v", "--verbose", "List each gem as it is installed") { @ui = UI.new(@err, verbose: true) }
        o.on("-h", "--help", "Show this help") do
          @out.puts o
          raise HelpShown
        end
      end
    end
  end
end
