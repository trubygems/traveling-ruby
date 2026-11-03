module TravelingRuby
  # Terminal output: colored when the stream is a terminal and NO_COLOR is not
  # set, plain otherwise (CI logs, pipes, tests)
  class UI
    COLORS = {red: 31, green: 32, yellow: 33, cyan: 36, bold: 1, dim: 2}.freeze

    attr_reader :io

    def initialize(io = $stderr, verbose: false, color: nil)
      @io = io
      @verbose = verbose
      @color = color.nil? ? io.respond_to?(:tty?) && io.tty? && ENV["NO_COLOR"].to_s.empty? : color
    end

    def verbose?
      @verbose
    end

    def say(message = "")
      @io.puts message
    end

    def title(message)
      say paint(message, :bold)
    end

    # A finished step: "  ✓ label  detail"
    def done(label, detail = nil)
      say "  #{paint("✓", :green)} #{label}#{"  #{paint(detail, :dim)}" if detail}"
    end

    def failed(label, detail = nil)
      say "  #{paint("✗", :red)} #{label}#{"  #{detail}" if detail}"
    end

    def hint(message)
      say "      #{paint("→ #{message}", :cyan)}"
    end

    def warn(message)
      say "#{paint("warning:", :yellow, :bold)} #{message}"
    end

    def error(message)
      say "#{paint("error:", :red, :bold)} #{message}"
    end

    # Shown with --verbose only
    def detail(message)
      say paint("    #{message}", :dim) if @verbose
    end

    # Downloads are worth seeing: they explain a slow first run
    def fetching(what)
      say paint("  ↓ #{what}", :dim)
    end

    def paint(text, *styles)
      return text.to_s unless @color
      "\e[#{styles.map { |style| COLORS.fetch(style) }.join(";")}m#{text}\e[0m"
    end

    def self.size(bytes)
      units = %w[B KB MB GB]
      value = bytes.to_f
      unit = units.shift
      while value >= 1024 && units.any?
        value /= 1024
        unit = units.shift
      end
      unit == "B" ? "#{bytes} B" : format("%.1f %s", value, unit)
    end

    def self.duration(seconds)
      seconds < 60 ? format("%.1fs", seconds) : format("%dm %ds", seconds / 60, seconds % 60)
    end
  end
end
