module TravelingRuby
  # The script at the top of a package that runs the app's entry point with the
  # packaged Ruby and the app's bundle
  module Launcher
    module_function

    def file_name(name, target)
      TravelingRuby.windows?(target) ? "#{name}.bat" : name
    end

    def render(target, entry:, gemfile: nil, ruby_opts: [])
      TravelingRuby.windows?(target) ? bat(entry, gemfile, ruby_opts) : sh(entry, gemfile, ruby_opts)
    end

    def sh(entry, gemfile, ruby_opts)
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
        #{bundle}exec "$LIBDIR/ruby/bin/ruby" #{args}"$LIBDIR/app/#{entry}" "$@"
      SH
    end

    def bat(entry, gemfile, ruby_opts)
      args = [*ruby_opts, *("-rbundler/setup" if gemfile)].map { |arg| "#{arg} " }.join
      entry = entry.tr("/", "\\")
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
        "%LIBDIR%\\ruby\\bin\\ruby.bat" #{args}"%LIBDIR%\\app\\#{entry}" %*
        exit /b %ERRORLEVEL%
      BAT
    end

    def sh_quote(arg)
      arg.match?(%r{\A[\w@%+=:,./-]+\z}) ? arg : "'#{arg.gsub("'", %q('\\\\''))}'"
    end
  end
end
