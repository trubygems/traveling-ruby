$LOAD_PATH.unshift(__dir__) unless $LOAD_PATH.include?(__dir__)

require "traveling_ruby/version"

module TravelingRuby
  class Error < StandardError; end

  # Targets that have a release, as named in release tags
  TARGETS = %w[
    linux-x86_64 linux-arm64
    linux-musl-x86_64 linux-musl-arm64
    macos-x86_64 macos-arm64
    windows-x86_64 windows-arm64
  ].freeze

  # Packaged when no targets are given
  DEFAULT_TARGETS = %w[linux-x86_64 linux-arm64 macos-x86_64 macos-arm64 windows-x86_64].freeze

  def self.windows?(target)
    target.start_with?("windows-")
  end

  autoload :Fetcher, "traveling_ruby/fetcher"
  autoload :Release, "traveling_ruby/release"
  autoload :Bundle, "traveling_ruby/bundle"
  autoload :Launcher, "traveling_ruby/launcher"
  autoload :Packager, "traveling_ruby/packager"
end
