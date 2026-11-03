require "json"
require "set"

module TravelingRuby
  # One Ruby version and revision of Traveling Ruby, published as a release per
  # target tagged ruby-<ruby>-<revision>-<target>. Each release has the runtime,
  # a tarball per native gem, SHA256SUMS and manifest.json.
  #
  # The source is a GitHub repository URL, or a local directory holding a
  # directory per release tag (handy for mirrors and testing).
  class Release
    DEFAULT_SOURCE = "https://github.com/trubygems/traveling-ruby".freeze

    attr_reader :ruby, :revision

    def self.resolve(fetcher:, source: DEFAULT_SOURCE, ruby: nil, revision: nil)
      source = source.chomp("/")
      if ruby.nil?
        raise Error, "set the Ruby version to use a local source" if fetcher.local?(source)
        tag = fetcher.redirect_location("#{source}/releases/latest").to_s.split("/").last
        match = tag.to_s.match(/\Aruby-([^-]+)-(\d+)-/)
        raise Error, "could not find the latest release at #{source}; set the Ruby version" unless match
        ruby = match[1]
        revision ||= match[2]
      end
      revision ||= newest_revision(fetcher, source, ruby)
      new(fetcher: fetcher, source: source, ruby: ruby, revision: revision.to_s)
    end

    # From versions/RUBY_REVISIONS.txt, one "<ruby> <revision>" per line
    def self.newest_revision(fetcher, source, ruby)
      url =
        if fetcher.local?(source)
          File.join(source, "RUBY_REVISIONS.txt")
        elsif (repo = source[%r{\Ahttps://github\.com/([^/]+/[^/]+)\z}, 1])
          "https://raw.githubusercontent.com/#{repo}/main/versions/RUBY_REVISIONS.txt"
        end
      revisions = url && fetcher.read(url)
      line = revisions.to_s.lines.map(&:split).find { |version, _| version == ruby }
      line ? line[1] : "0"
    end

    def initialize(fetcher:, source:, ruby:, revision:)
      @fetcher = fetcher
      @source = source
      @ruby = ruby
      @revision = revision
      @checksums = {}
      @manifests = {}
    end

    def to_s
      "#{ruby}-#{revision}"
    end

    def key(target)
      "#{ruby}-#{revision}-#{target}"
    end

    def tag(target)
      "ruby-#{key(target)}"
    end

    # The runtime tarball, downloaded and verified. The full runtime keeps what
    # the slim one leaves out, such as Ruby's headers and static libraries.
    def runtime(target, full: false)
      file =
        if full
          manifest(target).dig("runtime_full", "file") || "traveling-ruby-#{key(target)}-full.tar.gz"
        else
          manifest(target).dig("runtime", "file") || "traveling-ruby-#{key(target)}.tar.gz"
        end
      fetch(target, file)
    end

    # Full names (name-version) of the gems the runtime comes with: Ruby's
    # default and bundled gems
    def runtime_gems(target, full: false)
      @runtime_gems ||= {}
      @runtime_gems[[target, full]] ||= begin
        listing = IO.popen(["tar", "-tzf", runtime(target, full: full)], &:read)
        raise Error, "could not list #{File.basename(runtime(target, full: full))}" unless $?.success?
        listing.scan(%r{/specifications/(?:default/)?([^/\n]+)\.gemspec$}).flatten.to_set
      end
    end

    # Native gems built for target, as {name, version, file, sha256}
    def gems(target)
      manifest(target).fetch("gems", [])
    end

    # Versions of a native gem built for target
    def built_versions(target, name)
      gems(target).select { |gem| gem["name"] == name }.map { |gem| gem["version"] }
    end

    # The tarball of a native gem's extension, or nil when it was not built
    def gem_extension(target, name, version)
      gem = gems(target).find { |g| g["name"] == name && g["version"] == version }
      gem && fetch(target, gem["file"])
    end

    def manifest(target)
      @manifests[target] ||= begin
        body = @fetcher.read(url(target, "manifest.json"))
        raise Error, "no Traveling Ruby #{self} release for #{target} (#{url(target, "manifest.json")} not found)" unless body
        JSON.parse(body)
      end
    end

    private

    def fetch(target, file)
      sha256 = checksums(target)[file] or raise Error, "#{file} is not listed in #{tag(target)}'s SHA256SUMS"
      @fetcher.fetch(url(target, file), sha256: sha256, cache_key: File.join(tag(target), file))
    end

    def checksums(target)
      @checksums[target] ||= begin
        body = @fetcher.read(url(target, "SHA256SUMS")) or raise Error, "#{tag(target)} has no SHA256SUMS"
        body.lines.to_h do |line|
          sha256, file = line.strip.split(/ [ *]/, 2)
          [file, sha256]
        end
      end
    end

    def url(target, file)
      if @fetcher.local?(@source)
        File.join(@source, tag(target), file)
      else
        "#{@source}/releases/download/#{tag(target)}/#{file}"
      end
    end
  end
end
