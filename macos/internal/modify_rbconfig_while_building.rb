require 'rbconfig'

[RbConfig::CONFIG, RbConfig::MAKEFILE_CONFIG].each do |config|
  ldflags = config["LDFLAGS"].dup
  ldflags = ldflags.split(/ +/)

  ldflags.reject! { |x| x =~ /^-L/ }
  ldflags << "-L."
  ldflags << "-L#{ENV['RUNTIME_DIR']}/lib"
  ldflags << "-L#{ENV['TMPBUILDROOT']}/lib"
  ldflags << "-L/usr/lib"

  config["LDFLAGS"] = ldflags.join(" ")

  # Apple clang on macOS does not recognise -diag-disable=... (a flag from
  # Ruby's default CFLAGS). With -Werror this becomes a fatal error when
  # compiling native extensions (e.g. curses). Suppress unused-command-line
  # argument warnings so the flag is silently ignored.
  %w[CFLAGS CXXFLAGS].each do |key|
    next unless config.key?(key)
    flags = config[key].split(/ +/)
    flags.reject! { |x| x.start_with?('-diag-disable=') }
    flags << '-Wno-unused-command-line-argument' unless flags.include?('-Wno-unused-command-line-argument')
    config[key] = flags.join(' ')
  end
end
