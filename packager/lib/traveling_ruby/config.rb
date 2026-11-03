require "yaml"

module TravelingRuby
  # An app's packaging settings, from truby.yml (or .truby.yml) at its root:
  #
  #   name: pact
  #   version: 2.5.0
  #   ruby: 3.4.12
  #   targets: [linux-x86_64, linux-arm64, macos-arm64, windows-x86_64]
  #   bin:
  #     pact-broker: pact-broker.rb      # a script in the app
  #     rackup:                          # the app's bin/rackup, or a gem's rackup
  #   ruby_opts: [-EUTF-8]
  #   keep: [pact_broker/public]         # gem files that pruning would remove
  #
  # Settings given on the command line or to the Rake task win over the file.
  module Config
    FILES = %w[truby.yml .truby.yml].freeze

    # Setting in the file => Packager option
    KEYS = {
      "name" => :name,
      "version" => :app_version,
      "entry" => :entry,
      "bin" => :bins,
      "bins" => :bins,
      "targets" => :targets,
      "ruby" => :ruby,
      "revision" => :revision,
      "runtime" => :runtime,
      "source" => :source,
      "out" => :out,
      "without" => :without,
      "ruby_opts" => :ruby_opts,
      "keep" => :keep,
      "prune" => :prune,
      "archive" => :archive,
      "allow_missing_extensions" => :allow_missing_extensions
    }.freeze

    module_function

    def find(app_dir)
      FILES.map { |file| File.join(app_dir, file) }.find { |path| File.file?(path) }
    end

    # Packager options from the app's config file; {} when it has none
    def load(app_dir)
      path = find(app_dir) or return {}
      data = YAML.safe_load_file(path) || {}
      raise Error, "#{path} must hold a mapping of settings" unless data.is_a?(Hash)
      data.each_with_object({}) do |(key, value), options|
        option = KEYS[key.to_s] or raise Error, "#{File.basename(path)}: unknown setting #{key.inspect} (known: #{KEYS.keys.uniq.join(", ")})"
        options[option] = normalize(option, value)
      end
    end

    def normalize(option, value)
      case option
      when :bins then bins(value)
      when :targets, :without, :ruby_opts, :keep then value.is_a?(String) ? value.split(/[\s,]+/) : Array(value).map(&:to_s)
      when :prune, :archive, :allow_missing_extensions then value == true
      else value&.to_s
      end
    end

    # bin: as a mapping of launcher => script, or a list of launcher names
    def bins(value)
      case value
      when Hash then value.to_h { |name, script| [name.to_s, script&.to_s] }
      when Array then value.to_h { |name| [name.to_s, nil] }
      when String then {value => nil}
      else raise Error, "bin: must be a mapping of launcher names to scripts"
      end
    end

    # NAME or NAME=SCRIPT, as --bin takes
    def parse_bin(arg)
      name, script = arg.split("=", 2)
      raise Error, "--bin needs a name, as in --bin NAME or --bin NAME=SCRIPT" if name.to_s.empty?
      [name, script.to_s.empty? ? nil : script]
    end
  end
end
