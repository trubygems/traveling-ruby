require "test_helper"
require "json"
require "net/http"
require "open3"
require "socket"
require "stringio"
require "tmpdir"

# Packages the fixture apps with a real release for this machine and runs
# them: a small app with native gems, and two real-world ones, the Pact CLI
# and a Pact Broker.
# It downloads the runtime and gems, so it runs only with TRUBY_END_TO_END=1
# (rake test:end_to_end).
class EndToEndTest < Minitest::Test
  APP = File.join(FIXTURES, "app")
  PACT_CLI = File.join(FIXTURES, "pact-cli")
  PACT_BROKER = File.join(FIXTURES, "pact_broker")

  def setup
    skip "set TRUBY_END_TO_END=1 to package and run the fixture app" unless ENV["TRUBY_END_TO_END"]
    @target = host_target or skip "no Traveling Ruby target for #{RUBY_PLATFORM}"
    @out = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@out) if @out
  end

  def test_packages_an_app_with_native_gems_and_runs_it
    package = package(APP)

    # Through a symlinked directory, as macOS's /tmp and /var are
    linked = File.join(@out, "linked")
    File.symlink(package, linked) unless @target.start_with?("windows")
    output = run!(File.exist?(linked) ? linked : package, "app", "two words", "it's")

    result = JSON.parse(output)
    assert_equal "4.0.9", result["ruby"]
    assert_equal "3.1.0", result["json"], "the locked json, not Ruby's default gem"
    assert_equal "1.19.5", result["nokogiri"]
    assert_equal "2.10.2", result["sqlite3"]
    assert_equal "ok", result["rainbow"]
    assert_equal %w[nokogiri sqlite3], result["rows"]
    assert_equal ["two words", "it's"], result["args"]
  end

  # The Pact CLI, as pact-standalone ships it, publishing a pact to a Pact
  # Broker served by Puma on SQLite
  def test_packages_the_pact_cli_and_a_pact_broker
    skip "the Pact fixtures are locked for Linux and macOS" if @target.start_with?("windows")
    cli = package(PACT_CLI)
    {
      "pact-broker" => "1.78.0",
      "pact-message" => "0.11.1",
      "pact-mock-service" => "3.12.4",
      "pact-stub-service" => "3.12.4",
      "pact-provider-verifier" => "1.39.1"
    }.each { |bin, version| assert_equal version, run!(cli, bin, "version").lines.last.strip }
    assert_match(/pactflow publish-provider-contract/, run!(cli, "pactflow", "help"))

    broker = package(PACT_BROKER)
    port = free_port
    url = "http://127.0.0.1:#{port}"
    log = File.join(@out, "puma.log")
    env = { "PACT_BROKER_DATABASE_URL" => "sqlite://#{File.join(@out, 'broker.sqlite3')}" }
    puma = Bundler.with_unbundled_env do
      Process.spawn(env, launcher(broker, "puma"), File.join(broker, "lib", "app", "config.ru"),
                    "-b", "tcp://127.0.0.1:#{port}", out: log, err: log, chdir: @out)
    end
    begin
      heartbeat = wait_for("#{url}/diagnostic/status/heartbeat") or flunk "the broker did not start:\n#{File.read(log)}"
      assert_equal true, JSON.parse(heartbeat)["ok"]

      pact = File.join(@out, "Foo-Bar.json")
      File.write(pact, JSON.generate(
        consumer: { name: "Foo" }, provider: { name: "Bar" },
        interactions: [{ description: "a request", request: { method: "GET", path: "/thing" },
                         response: { status: 200, body: { ok: true } } }],
        metadata: { pactSpecification: { version: "2.0.0" } }
      ))
      run!(cli, "pact-broker", "publish", pact, "--consumer-app-version", "1.0.0", "--branch", "main",
           "--broker-base-url", url)
      published = JSON.parse(Net::HTTP.get(URI("#{url}/pacts/provider/Bar/consumer/Foo/latest")))
      assert_equal "/thing", published["interactions"].first["request"]["path"]
      refute_match(/ERROR/, File.binread(log), "the broker logged errors")
    ensure
      Process.kill("TERM", puma)
      Process.wait(puma)
    end
  end

  private

  # Checks and packages the app for this machine, and returns the package
  def package(app)
    assert_equal 0, truby("check", app, "--targets", @target)
    assert_equal 0, truby("package", app, "--targets", @target, "--out", @out, "--no-archive")
    name = File.read(File.join(app, "truby.yml"))[/^name: (\S+)/, 1] || File.basename(app)
    File.join(@out, "#{name}-#{@target}")
  end

  def launcher(package, bin)
    File.join(package, TravelingRuby::Launcher.file_name(bin, @target))
  end

  # Runs a launcher outside this test's bundle, and returns its output
  def run!(package, bin, *args)
    command = launcher(package, bin)
    output, error, status = Bundler.with_unbundled_env { Open3.capture3(command, *args) }
    assert status.success?, "#{command} #{args.join(' ')} failed:\n#{output}#{error}"
    output
  end

  def free_port
    server = TCPServer.new("127.0.0.1", 0)
    server.addr[1]
  ensure
    server&.close
  end

  # The body of the first successful GET of url, or nil after a minute
  def wait_for(url)
    60.times do
      begin
        response = Net::HTTP.get_response(URI(url))
        return response.body if response.is_a?(Net::HTTPSuccess)
      rescue SystemCallError
        # Not listening yet
      end
      sleep 1
    end
    nil
  end

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
