# encoding: utf-8
# immutable: string

IN_TRAVELING_RUBY = true

restorable_envs = ['DYLD_LIBRARY_PATH', 'TERMINFO', 'RUBYOPT', 'RUBYLIB'].freeze
restorable_envs.each do |name|
  ENV[name] = ENV["ORIG_#{name}"]
  ENV.delete("ORIG_#{name}")
end

# We can't restore these environments now because they'll be used later.
# We just store the original values so that the program can decide what to do.
$OVERRIDDEN_ENVIRONMENTS = {
  'SSL_CERT_DIR'  => ENV['OLD_SSL_CERT_DIR'],
  'SSL_CERT_FILE' => ENV['OLD_SSL_CERT_FILE']
}

# The wrapper puts our lib/ruby directories on RUBYLIB, and RUBYLIB entries come
# before the point where RubyGems inserts activated gems. That lets default gems
# in the stdlib (e.g. prism, json) shadow newer installed versions, so move our
# entries behind that point, as they would be without RUBYLIB.
traveling_ruby_lib = File.expand_path('..', __dir__) + '/'
traveling_ruby_paths, other_paths = $LOAD_PATH.partition { |path| path.start_with?(traveling_ruby_lib) }
$LOAD_PATH.replace(other_paths + traveling_ruby_paths)
