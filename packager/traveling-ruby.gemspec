require_relative "lib/traveling_ruby/version"

Gem::Specification.new do |spec|
  spec.name = "traveling-ruby"
  spec.version = TravelingRuby::VERSION
  spec.authors = ["Yousaf Nabi"]
  spec.summary = "truby: package Ruby apps to run on Linux, macOS and Windows with no Ruby installed"
  spec.description = <<~DESC
    Builds self-contained packages of a Ruby app for each platform Traveling Ruby
    supports: the app, its gems, the prebuilt native extensions they need and a
    portable Ruby, behind a launcher script. No Ruby is needed to run them.
  DESC
  spec.homepage = "https://github.com/trubygems/traveling-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"
  spec.metadata = {
    "source_code_uri" => "https://github.com/trubygems/traveling-ruby/tree/main/packager",
    "bug_tracker_uri" => "https://github.com/trubygems/traveling-ruby/issues",
    "rubygems_mfa_required" => "true"
  }
  spec.files = Dir["lib/**/*.rb", "exe/*", "README.md", "LICENSE.md"]
  spec.bindir = "exe"
  spec.executables = ["truby", "traveling-ruby"]
end
