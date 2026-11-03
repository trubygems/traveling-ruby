require "test_helper"
require "stringio"
require "tmpdir"

class CLITest < Minitest::Test
  def run_cli(*argv)
    out = StringIO.new
    err = StringIO.new
    status = TravelingRuby::CLI.new(out: out, err: err).run(argv)
    [status, out.string, err.string]
  end

  def test_help_describes_a_portable_ruby
    status, out, = run_cli("--help")
    assert_equal 0, status
    assert_match(/portable Ruby/, out)
    assert_match(/truby <command>/, out)
  end

  def test_command_help_exits_cleanly
    status, out, = run_cli("package", "--help")
    assert_equal 0, status
    assert_match(/--bin NAME\[=SCRIPT\]/, out)
  end

  def test_version
    assert_equal [0, "truby #{TravelingRuby::VERSION}\n", ""], run_cli("version")
  end

  def test_unknown_command_fails
    status, _, err = run_cli("frobnicate")
    assert_equal 1, status
    assert_match(/unknown command "frobnicate"/, err)
  end

  def test_init_writes_truby_yml_once
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "exe"))
      File.write(File.join(dir, "exe", "hello"), "puts 1")
      File.write(File.join(dir, "VERSION"), "0.3.0\n")
      status, = run_cli("init", dir)
      assert_equal 0, status
      config = TravelingRuby::Config.load(dir)
      assert_equal "0.3.0", config[:app_version]
      assert_equal({"hello" => "exe/hello"}, config[:bins])

      status, _, err = run_cli("init", dir)
      assert_equal 1, status
      assert_match(/already exists/, err)
      assert_equal 0, run_cli("init", "--force", dir).first
    end
  end
end
