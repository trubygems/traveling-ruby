require "test_helper"
require "tmpdir"

class ConfigTest < Minitest::Test
  def test_no_file_means_no_settings
    Dir.mktmpdir { |dir| assert_equal({}, TravelingRuby::Config.load(dir)) }
  end

  def test_reads_settings_into_packager_options
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "truby.yml"), <<~YAML)
        name: pact
        version: 2.5.0
        targets: linux-x86_64, macos-arm64
        bin:
          pact-broker: pact-broker.rb
          rackup:
        ruby_opts: [-EUTF-8]
        keep: [pact_broker/public]
        prune: false
      YAML
      options = TravelingRuby::Config.load(dir)
      assert_equal "pact", options[:name]
      assert_equal "2.5.0", options[:app_version]
      assert_equal %w[linux-x86_64 macos-arm64], options[:targets]
      assert_equal({"pact-broker" => "pact-broker.rb", "rackup" => nil}, options[:bins])
      assert_equal %w[-EUTF-8], options[:ruby_opts]
      assert_equal %w[pact_broker/public], options[:keep]
      assert_equal false, options[:prune]
    end
  end

  def test_takes_bin_as_a_list_of_names
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".truby.yml"), "bin: [one, two]\n")
      assert_equal({"one" => nil, "two" => nil}, TravelingRuby::Config.load(dir)[:bins])
    end
  end

  def test_rejects_unknown_settings
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "truby.yml"), "target: linux-x86_64\n")
      error = assert_raises(TravelingRuby::Error) { TravelingRuby::Config.load(dir) }
      assert_match(/unknown setting "target"/, error.message)
    end
  end

  def test_parses_bin_arguments
    assert_equal ["app", nil], TravelingRuby::Config.parse_bin("app")
    assert_equal ["app", "lib/app.rb"], TravelingRuby::Config.parse_bin("app=lib/app.rb")
    assert_raises(TravelingRuby::Error) { TravelingRuby::Config.parse_bin("=x") }
  end
end
