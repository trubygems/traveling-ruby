require "optparse"

module TravelingRuby
  class CLI
    def initialize(out: $stdout, err: $stderr)
      @out = out
      @err = err
    end

    def run(argv)
      argv = argv.dup
      case (command = argv.shift)
      when "package" then package(argv)
      when "targets" then @out.puts(TARGETS) || 0
      when "version", "--version", "-v" then @out.puts(VERSION) || 0
      when nil, "help", "--help", "-h" then @out.puts(usage) || 0
      else
        @err.puts "unknown command: #{command}\n\n#{usage}"
        1
      end
    rescue Error, OptionParser::ParseError => e
      @err.puts "traveling-ruby: #{e.message}"
      1
    end

    private

    def usage
      <<~USAGE
        Usage: traveling-ruby <command>

        Commands:
          package [options] [APP_DIR]  Package an app with Traveling Ruby
          targets                      List the targets
          version                      Show the version

        Run traveling-ruby package --help for the package options.
      USAGE
    end

    def package(argv)
      options = {ruby_opts: []}
      parser = OptionParser.new do |o|
        o.banner = "Usage: traveling-ruby package [options] [APP_DIR]"
        o.separator ""
        o.separator "Packages the app in APP_DIR (default .) for each target, with its Gemfile.lock's gems."
        o.separator ""
        o.on("--name NAME", "Package and launcher name (default: the app directory's name)") { |v| options[:name] = v }
        o.on("--entry PATH", "Script to run, relative to the app (default: bin/NAME or exe/NAME)") { |v| options[:entry] = v }
        o.on("--targets LIST", Array, "Comma-separated targets (default: #{DEFAULT_TARGETS.join(",")})") { |v| options[:targets] = v }
        o.on("--ruby VERSION", "Ruby version (default: the latest release's)") { |v| options[:ruby] = v }
        o.on("--revision N", "Release revision (default: the newest for the Ruby version)") { |v| options[:revision] = v }
        o.on("--source URL_OR_DIR", "GitHub repository or local release directory (default: #{Release::DEFAULT_SOURCE})") { |v| options[:source] = v }
        o.on("--out DIR", "Output directory, relative to the app (default: pkg)") { |v| options[:out] = v }
        o.on("--app-version VERSION", "Version to put in package names") { |v| options[:app_version] = v }
        o.on("--without GROUPS", Array, "Gem groups to leave out (default: development,test)") { |v| options[:without] = v }
        o.on("--ruby-opt OPT", "Option for ruby in the launcher, e.g. --yjit (repeatable)") { |v| options[:ruby_opts] << v }
        o.on("--cache DIR", "Download cache (default: #{Fetcher.default_cache_dir})") { |v| options[:cache_dir] = v }
        o.on("--strict", "Fail when a native gem has no extension built for a target") { options[:strict] = true }
        o.on("--[no-]prune", "Remove gems' tests, docs and extension sources (default: on)") { |v| options[:prune] = v }
        o.on("--[no-]archive", "Make a .tar.gz of each package and SHA256SUMS (default: on)") { |v| options[:archive] = v }
        o.on("-h", "--help", "Show this help") do
          @out.puts o
          return 0
        end
      end
      args = parser.parse(argv)
      raise OptionParser::InvalidArgument, "one app directory at most" if args.size > 1
      Packager.new(app_dir: args.first || ".", log: @err, **options).run.each { |path| @out.puts path }
      0
    end
  end
end
