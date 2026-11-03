require "rake"
require "rake/tasklib"
require "traveling_ruby"

module TravelingRuby
  # Defines a task that packages the app for its targets, and a task per target:
  #
  #   require "traveling_ruby/rake_task"
  #   TravelingRuby::RakeTask.new do |t|
  #     t.bins = {"hello" => "bin/hello"}
  #     t.ruby_opts = ["-EUTF-8"]
  #   end
  #
  #   rake package               # every target
  #   rake package:linux-arm64   # one target
  #   rake package:check         # check the app is ready to package
  #
  # Settings left unset come from truby.yml, when the app has one.
  class RakeTask < Rake::TaskLib
    SETTINGS = %i[name entry bins targets ruby revision runtime source out app_version without ruby_opts keep
                  prune archive allow_missing_extensions cache_dir].freeze

    attr_accessor(*SETTINGS, :app_dir, :verbose)

    def initialize(task_name = :package)
      super()
      @task_name = task_name
      @app_dir = Rake.application.original_dir
      yield self if block_given?
      define
    end

    private

    def define
      desc "Package the app with Traveling Ruby"
      task(@task_name) { packager.run }

      namespace @task_name do
        desc "Check the app is ready to package with Traveling Ruby"
        task(:check) { packager.check or abort }

        TARGETS.each do |target|
          desc "Package the app with Traveling Ruby for #{target}"
          task(target) { packager(targets: [target]).run }
        end
      end
    end

    def packager(**overrides)
      settings = SETTINGS.to_h { |setting| [setting, public_send(setting)] }.compact
      Packager.new(app_dir: app_dir, ui: UI.new(verbose: verbose == true),
                   **Config.load(app_dir).merge(settings, overrides))
    end
  end
end
