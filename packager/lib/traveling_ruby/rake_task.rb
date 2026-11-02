require "rake"
require "rake/tasklib"
require "traveling_ruby"

module TravelingRuby
  # Defines a task that packages the app for its targets, and a task per target:
  #
  #   require "traveling_ruby/rake_task"
  #   TravelingRuby::RakeTask.new do |t|
  #     t.entry = "bin/hello"
  #     t.ruby_opts = ["--yjit"]
  #   end
  #
  #   rake package               # every target
  #   rake package:linux-arm64   # one target
  class RakeTask < Rake::TaskLib
    attr_accessor :name, :entry, :targets, :ruby, :revision, :source, :out, :app_version,
                  :without, :ruby_opts, :strict, :prune, :archive, :cache_dir, :app_dir

    def initialize(task_name = :package)
      super()
      @task_name = task_name
      @app_dir = Rake.application.original_dir
      @targets = DEFAULT_TARGETS
      @source = Release::DEFAULT_SOURCE
      @out = "pkg"
      @without = %w[development test]
      @ruby_opts = []
      @strict = false
      @prune = true
      @archive = true
      yield self if block_given?
      define
    end

    private

    def define
      desc "Package the app with Traveling Ruby for #{targets.join(", ")}"
      task(@task_name) { packager(targets).run }

      namespace @task_name do
        TARGETS.each do |target|
          desc "Package the app with Traveling Ruby for #{target}"
          task(target) { packager([target]).run }
        end
      end
    end

    def packager(targets)
      Packager.new(
        app_dir: app_dir, name: name, entry: entry, targets: targets, ruby: ruby, revision: revision,
        source: source, out: out, app_version: app_version, without: without, ruby_opts: ruby_opts,
        strict: strict, prune: prune, archive: archive, cache_dir: cache_dir
      )
    end
  end
end
