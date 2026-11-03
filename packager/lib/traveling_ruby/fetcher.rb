require "digest"
require "fileutils"
require "net/http"
require "uri"

module TravelingRuby
  # Downloads over HTTP(S), or reads local paths and file:// URLs. Files fetched
  # with a checksum are cached by name and verified, both when downloaded and
  # when reused.
  class Fetcher
    MAX_REDIRECTS = 10

    def initialize(cache_dir: self.class.default_cache_dir, ui: UI.new)
      @cache_dir = cache_dir
      @ui = ui
    end

    def self.default_cache_dir
      base = ENV["XDG_CACHE_HOME"]
      base = File.join(Dir.home, ".cache") if base.nil? || base.empty?
      File.join(base, "traveling-ruby")
    end

    # The body at url, or nil when it does not exist
    def read(url)
      if local?(url)
        path = local_path(url)
        File.exist?(path) ? File.binread(path) : nil
      else
        get(url) { |response| response.body }
      end
    end

    # A local copy of url, kept at <cache dir>/<cache_key> and verified when
    # sha256 is given
    def fetch(url, sha256:, cache_key:)
      path = File.join(@cache_dir, cache_key)
      return path if File.exist?(path) && (sha256.nil? || Digest::SHA256.file(path).hexdigest == sha256)

      FileUtils.mkdir_p(File.dirname(path))
      tmp = "#{path}.#{Process.pid}.tmp"
      begin
        if local?(url)
          source = local_path(url)
          raise Error, "#{source} does not exist" unless File.exist?(source)
          FileUtils.cp(source, tmp)
        else
          @ui.fetching(url)
          found = get(url) do |response|
            File.open(tmp, "wb") { |f| response.read_body { |chunk| f.write(chunk) } }
          end
          raise Error, "#{url} not found" unless found
        end
        actual = Digest::SHA256.file(tmp).hexdigest
        raise Error, "checksum mismatch for #{url}: expected #{sha256}, got #{actual}" unless sha256.nil? || actual == sha256
        File.rename(tmp, path)
      ensure
        FileUtils.rm_f(tmp)
      end
      path
    end

    # Where url redirects to, without following it
    def redirect_location(url)
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(Net::HTTP::Head.new(uri))
      end
      response["location"] if response.is_a?(Net::HTTPRedirection)
    end

    def local?(url)
      !url.match?(%r{\A[a-z][a-z0-9+.-]*://}i) || url.start_with?("file://")
    end

    private

    def local_path(url)
      url.start_with?("file://") ? URI(url).path : url
    end

    # Yields the response, following redirects; nil when not found
    def get(url, redirects = 0, &block)
      raise Error, "too many redirects fetching #{url}" if redirects > MAX_REDIRECTS

      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(Net::HTTP::Get.new(uri)) do |response|
          case response
          when Net::HTTPRedirection
            return get(URI.join(url, response["location"]).to_s, redirects + 1, &block)
          when Net::HTTPNotFound
            return nil
          when Net::HTTPSuccess
            return yield(response)
          else
            raise Error, "GET #{url}: #{response.code} #{response.message}"
          end
        end
      end
    end
  end
end
