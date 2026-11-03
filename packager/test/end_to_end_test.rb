require "test_helper"
require "json"
require "open3"
require "stringio"
require "tmpdir"

# Packages the fixture app with a real release for this machine and runs it.
# It downloads the runtime and gems, so it runs only with TRUBY_END_TO_END=1
# (rake test:end_to_end).
class EndToEndTest < Minitest::Test
  APP = File.join(FIXTURES, "app")

  def setup
    skip "set TRUBY_END_TO_END=1 to package and run the fixture app" unless ENV["TRUBY_END_TO_END"]
    @target = host_target or skip "no Traveling Ruby target for #{RUBY_PLATFORM}"
    @out = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@out) if @out
  end

  def test_packages_an_app_with_native_gems_and_runs_it
    assert_equal 0, truby("check", APP, "--targets", @target)
    assert_equal 0, truby("package", APP, "--targets", @target, "--out", @out, "--no-archive")

    # Through a symlinked directory, as macOS's /tmp and /var are
    package = File.join(@out, "app-#{@target}")
    linked = File.join(@out, "linked")
    File.symlink(package, linked) unless @target.start_with?("windows")
    launcher = File.join(File.exist?(linked) ? linked : package, TravelingRuby::Launcher.file_name("app", @target))
    output, error, status = Bundler.with_unbundled_env { Open3.capture3(launcher, "two words", "it's") }
    assert status.success?, "#{launcher} failed:\n#{output}#{error}"

    result = JSON.parse(output)
    assert_equal "4.0.9", result["ruby"]
    assert_equal "3.1.0", result["json"], "the locked json, not Ruby's default gem"
    assert_equal "1.19.5", result["nokogiri"]
    assert_equal "2.10.2", result["sqlite3"]
    assert_equal "ok", result["rainbow"]
    assert_equal %w[nokogiri sqlite3], result["rows"]
    assert_equal ["two words", "it's"], result["args"]
  end

  private

  def truby(*argv)
    err = StringIO.new
    status = TravelingRuby::CLI.new(out: StringIO.new, err: err).run(argv)
    puts err.string if status != 0 || ENV["VERBOSE"]
    status
  end

  def host_target
    os = case RbConfig::CONFIG["host_os"]
         when /darwin/ then "macos"
         when /linux-musl/ then "linux-musl"
         when /linux/ then File.exist?("/etc/alpine-release") ? "linux-musl" : "linux"
         when /mingw|mswin/ then "windows"
         end
    arch = case RbConfig::CONFIG["host_cpu"]
           when /arm64|aarch64/ then "arm64"
           when /x86_64|x64/ then "x86_64"
           end
    target = "#{os}-#{arch}"
    target if TravelingRuby::TARGETS.include?(target)
  end
end
