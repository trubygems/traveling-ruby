require "test_helper"

class LauncherTest < Minitest::Test
  def test_sh_runs_the_script_with_bundler
    script = TravelingRuby::Launcher.render("linux-x86_64", script: "app/bin/app", gemfile: "Gemfile", ruby_opts: ["--yjit"])
    assert script.start_with?("#!/bin/sh\n")
    assert_includes script, %(export BUNDLE_GEMFILE="$LIBDIR/app/Gemfile"\n)
    assert_includes script, %(exec "$LIBDIR/ruby/bin/ruby" --yjit -rbundler/setup "$LIBDIR/app/bin/app" "$@"\n)
  end

  def test_sh_without_a_gemfile_skips_bundler
    script = TravelingRuby::Launcher.render("macos-arm64", script: "app/app.rb")
    refute_includes script, "BUNDLE_"
    assert_includes script, %(exec "$LIBDIR/ruby/bin/ruby" "$LIBDIR/app/app.rb" "$@"\n)
  end

  def test_sh_quotes_ruby_options
    script = TravelingRuby::Launcher.render("linux-arm64", script: "app/app.rb", ruby_opts: ["-W:no-deprecated", "-e 'x'"])
    assert_includes script, %(-W:no-deprecated '-e '\\''x'\\''' )
  end

  def test_bat_for_windows
    assert_equal "app.bat", TravelingRuby::Launcher.file_name("app", "windows-x86_64")
    script = TravelingRuby::Launcher.render("windows-x86_64", script: "app/bin/app", gemfile: "Gemfile")
    assert(script.lines.all? { |line| line.end_with?("\r\n") && !line.end_with?("\r\r\n") })
    assert_includes script, %(set "BUNDLE_GEMFILE=%LIBDIR%\\app\\Gemfile"\r\n)
    assert_includes script, %("%LIBDIR%\\ruby\\bin\\ruby.bat" -rbundler/setup "%LIBDIR%\\app\\bin\\app" %*\r\n)
  end

  def test_runs_a_gem_executable
    script = TravelingRuby::Launcher.render("linux-x86_64", script: "ruby/lib/ruby/gems/3.4.0/gems/rack-3.1.0/exe/rackup", gemfile: "Gemfile")
    assert_includes script, %("$LIBDIR/ruby/lib/ruby/gems/3.4.0/gems/rack-3.1.0/exe/rackup" "$@"\n)
  end
end
