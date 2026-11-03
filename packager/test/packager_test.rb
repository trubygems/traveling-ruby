require "test_helper"
require "stringio"
require "tmpdir"

class PackagerTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    write "bin/tool", "puts 1"
    write "server.rb", "puts 2"
    write "scripts/worker", "puts 3"
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def write(path, content)
    FileUtils.mkdir_p(File.join(@dir, File.dirname(path)))
    File.write(File.join(@dir, path), content)
  end

  def packager(**options)
    TravelingRuby::Packager.new(app_dir: @dir, ui: TravelingRuby::UI.new(StringIO.new), **options)
  end

  def test_defaults_to_bin_named_after_the_app
    programs = packager(name: "tool").programs
    assert_equal [["tool", "bin/tool"]], programs.map { |p| [p.name, p.script] }
  end

  def test_finds_each_bins_script
    programs = packager(bins: {"tool" => nil, "server" => nil, "worker" => "scripts/worker"}).programs
    assert_equal [["tool", "bin/tool"], ["server", "server.rb"], ["worker", "scripts/worker"]],
                 programs.map { |p| [p.name, p.script] }
    refute programs.any?(&:gem?)
  end

  def test_entry_names_the_package_launcher
    assert_equal [["mine", "server.rb"]], packager(name: "mine", entry: "server.rb").programs.map { |p| [p.name, p.script] }
  end

  def test_explains_a_missing_script
    error = assert_raises(TravelingRuby::Error) { packager(bins: {"x" => "nope.rb"}).programs }
    assert_match(/x: nope\.rb not found/, error.message)
    error = assert_raises(TravelingRuby::Error) { packager(bins: {"ghost" => nil}).programs }
    assert_match(/no bin\/ghost, exe\/ghost or ghost\.rb/, error.message)
  end

  def test_explains_nothing_to_launch
    error = assert_raises(TravelingRuby::Error) { packager(name: "other").programs }
    assert_match(/nothing to launch/, error.message)
  end

  def test_rejects_unknown_targets_and_runtimes
    assert_raises(TravelingRuby::Error) { packager(targets: %w[plan9-mips]) }
    assert_raises(TravelingRuby::Error) { packager(runtime: "huge") }
  end

  def test_package_names_include_the_version
    assert_equal "tool-1.2.0-linux-x86_64", packager(name: "tool", app_version: "1.2.0").package_name("linux-x86_64")
  end
end
