$: << File.join(File.dirname(__FILE__), 'lib')

require 'router'

CONFIG_FILE = File.join('config', 'config.rb')
CONFIG = eval(File.read(CONFIG_FILE), binding, CONFIG_FILE, 1) rescue \
	raise(::ArgumentError, "Failed to read #{CONFIG_FILE}: #{$!}")

unless CONFIG[:session_secret] then
	raise(::ArgumentError, "Set a :session_secret in #{CONFIG_FILE}")
end
unless CONFIG[:backend] then
	raise(::ArgumentError, "Set a :backend in #{CONFIG_FILE}")
end

use Rack::Session::Cookie, :secret => CONFIG[:session_secret]
use Rack::ContentType, "text/html"
run ::Router.new(CONFIG)
