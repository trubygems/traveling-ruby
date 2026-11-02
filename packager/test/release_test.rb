require "test_helper"
require "tmpdir"
require "json"
require "digest"
require "stringio"

class ReleaseTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @tag_dir = File.join(@dir, "ruby-3.4.12-1-linux-arm64")
    FileUtils.mkdir_p(@tag_dir)
    write("traveling-ruby-3.4.12-1-linux-arm64.tar.gz", "runtime")
    write("traveling-ruby-gems-3.4.12-1-linux-arm64-json-3.1.0.tar.gz", "json")
    sums = Dir.children(@tag_dir).sort.map { |f| "#{Digest::SHA256.file(File.join(@tag_dir, f)).hexdigest}  #{f}\n" }
    write("SHA256SUMS", sums.join)
    write("manifest.json", JSON.generate(
      runtime: {file: "traveling-ruby-3.4.12-1-linux-arm64.tar.gz"},
      gems: [{name: "json", version: "3.1.0", file: "traveling-ruby-gems-3.4.12-1-linux-arm64-json-3.1.0.tar.gz"}]
    ))
    File.write(File.join(@dir, "RUBY_REVISIONS.txt"), "3.4.12 1\n3.3.13 0\n")
    @fetcher = TravelingRuby::Fetcher.new(cache_dir: File.join(@dir, "cache"), log: StringIO.new)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def write(file, content)
    File.write(File.join(@tag_dir, file), content)
  end

  def test_resolves_the_revision_and_fetches_verified_files
    release = TravelingRuby::Release.resolve(fetcher: @fetcher, source: @dir, ruby: "3.4.12")
    assert_equal "ruby-3.4.12-1-linux-arm64", release.tag("linux-arm64")
    assert_equal "runtime", File.read(release.runtime("linux-arm64"))
    assert_equal "json", File.read(release.gem_extension("linux-arm64", "json", "3.1.0"))
    assert_nil release.gem_extension("linux-arm64", "json", "2.0.0")
  end

  def test_rejects_a_tampered_file
    release = TravelingRuby::Release.resolve(fetcher: @fetcher, source: @dir, ruby: "3.4.12")
    write("traveling-ruby-3.4.12-1-linux-arm64.tar.gz", "tampered")
    error = assert_raises(TravelingRuby::Error) { release.runtime("linux-arm64") }
    assert_match(/checksum mismatch/, error.message)
  end

  def test_missing_target
    release = TravelingRuby::Release.resolve(fetcher: @fetcher, source: @dir, ruby: "3.4.12")
    assert_raises(TravelingRuby::Error) { release.runtime("macos-arm64") }
  end
end
