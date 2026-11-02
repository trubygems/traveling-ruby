# Traveling Ruby: activate gems ahead of the bundled standard library.
#
# Installed as rubygems/defaults/operating_system.rb, which RubyGems loads
# while booting, before any -r library.
#
# Ruby is built with --prefix /tmp/ruby and then relocated, so bin/ruby passes
# the real standard library paths through RUBYLIB. RubyGems treats RUBYLIB like
# -I and inserts activated gems after it, behind the stdlib copies of default
# gems (json, psych, prism...), mixing two versions of one library.
#
# A normal Ruby marks its first built-in load path (sitelibdir) with
# @gem_prelude_index, and RubyGems inserts gems there. Mark the relocated
# sitelibdir from RUBYLIB instead, so gems load ahead of the stdlib, as they do
# on a normal Ruby, while user -I and RUBYLIB entries still come first.
index = $LOAD_PATH.index(RbConfig::CONFIG["sitelibdir"])
marked = $LOAD_PATH.index { |path| path.instance_variable_defined?(:@gem_prelude_index) }
if index && (marked.nil? || index < marked)
  path = $LOAD_PATH[index].dup
  path.instance_variable_set(:@gem_prelude_index, path)
  $LOAD_PATH[index] = path
end
