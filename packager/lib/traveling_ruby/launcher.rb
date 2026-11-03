module TravelingRuby
  # A script at the top of a package that runs one of its programs with the
  # packaged Ruby and the app's bundle. The script to run is relative to lib/:
  # app/bin/hello for the app's own, or a gem's executable in ruby/lib/ruby/gems.
  module Launcher
    module_function

    def file_name(name, target)
      TravelingRuby.windows?(target) ? "#{name}.bat" : name
    end

    def render(target, script:, gemfile: nil, ruby_opts: [])
      TravelingRuby.windows?(target) ? bat(script, gemfile, ruby_opts) : sh(script, gemfile, ruby_opts)
    end

    def sh(script, gemfile, ruby_opts)
      args = [*ruby_opts, *("-rbundler/setup" if gemfile)].map { |arg| "#{sh_quote(arg)} " }.join
      bundle = <<~SH if gemfile
        export BUNDLE_GEMFILE="$LIBDIR/app/#{gemfile}"
        export BUNDLE_APP_CONFIG="$LIBDIR/bundle"
        unset BUNDLE_PATH BUNDLE_IGNORE_CONFIG RUBYGEMS_GEMDEPS
      SH
      <<~SH
        #!/bin/sh
        set -e
        SELF="$0"
        while [ -h "$SELF" ]; do
          LINK=$(readlink "$SELF")
          case "$LINK" in
            /*) SELF="$LINK" ;;
            *) SELF="$(dirname "$SELF")/$LINK" ;;
          esac
        done
        LIBDIR=$(cd "$(dirname "$SELF")/lib" && pwd)
        #{bundle}exec "$LIBDIR/ruby/bin/ruby" #{args}"$LIBDIR/#{script}" "$@"
      SH
    end

    def bat(script, gemfile, ruby_opts)
      args = [*ruby_opts, *("-rbundler/setup" if gemfile)].map { |arg| "#{arg} " }.join
      script = script.tr("/", "\\")
      bundle = <<~BAT if gemfile
        set "BUNDLE_GEMFILE=%LIBDIR%\\app\\#{gemfile}"
        set "BUNDLE_APP_CONFIG=%LIBDIR%\\bundle"
        set BUNDLE_PATH=
        set BUNDLE_IGNORE_CONFIG=
        set RUBYGEMS_GEMDEPS=
      BAT
      <<~BAT.gsub("\n", "\r\n")
        @echo off
        setlocal
        set "LIBDIR=%~dp0lib"
        #{bundle&.chomp}
        "%LIBDIR%\\ruby\\bin\\ruby.bat" #{args}"%LIBDIR%\\#{script}" %*
        exit /b %ERRORLEVEL%
      BAT
    end

    def sh_quote(arg)
      arg.match?(%r{\A[\w@%+=:,./-]+\z}) ? arg : "'#{arg.gsub("'", %q('\\\\''))}'"
    end
  end
end
