require "test_helper"

class BundleTest < Minitest::Test
  def setup
    @bundle = TravelingRuby::Bundle.find(File.join(FIXTURES, "app"))
  end

  def test_selects_locked_gems_outside_development_and_test
    names = @bundle.gems("linux-arm64").map(&:full_name)
    assert_equal %w[json-3.1.0 mini_portile2-2.8.9 nokogiri-1.19.4 racc-1.8.1 rainbow-3.1.1 sqlite3-2.10.2], names
  end

  def test_uses_ruby_platform_checksums_and_remotes
    nokogiri = @bundle.gems("linux-arm64").find { |gem| gem.name == "nokogiri" }
    assert_equal "50c951611c92bca05c51411aef45f1cbc50f2821c4802758c5c6d34696533ab5", nokogiri.checksum
    assert_equal ["https://rubygems.org/"], nokogiri.remotes
  end

  def test_includes_gems_limited_to_windows_only_on_windows
    refute_includes @bundle.gems("linux-x86_64").map(&:name), "tzinfo-data"
    # tzinfo-data is not locked for any platform here, so it is skipped rather than fetched
    refute_includes @bundle.gems("windows-x86_64").map(&:name), "tzinfo-data"
  end

  def test_includes_groups_that_are_not_left_out
    bundle = TravelingRuby::Bundle.find(File.join(FIXTURES, "app"), without: [])
    assert_includes bundle.gems("linux-arm64").map(&:name), "minitest"
  end

  def test_packaged_lockfile_locks_only_the_ruby_platform
    lockfile = @bundle.packaged_lockfile(checksums: {"rainbow-3.1.1" => "a" * 64}, bundler_version: "9.9.9")
    refute_match(/-(aarch64|x86_64|arm64|arm|x86)-/, lockfile)
    assert_match(/^PLATFORMS\n  ruby\n\n/, lockfile)
    assert_match(/^    nokogiri \(1\.19\.4\)\n      mini_portile2 \(~> 2\.8\.2\)\n      racc \(~> 1\.4\)\n    prism/, lockfile)
    assert_includes lockfile, "  rainbow (3.1.1) sha256=#{"a" * 64}\n"
    assert_includes lockfile, "  nokogiri (1.19.4) sha256=50c951611c92bca05c51411aef45f1cbc50f2821c4802758c5c6d34696533ab5\n"
    assert_match(/^BUNDLED WITH\n  9\.9\.9\n\z/, lockfile)
  end

  def test_packaged_lockfile_is_accepted_by_bundler
    lockfile = @bundle.packaged_lockfile(checksums: {}, bundler_version: "4.0.20")
    parser = Bundler::LockfileParser.new(lockfile)
    assert_equal [Gem::Platform::RUBY], parser.platforms.map(&:to_s)
    assert(parser.specs.all? { |spec| spec.platform.to_s == "ruby" })
    assert_equal 1, parser.specs.count { |spec| spec.name == "sqlite3" }
  end
end
