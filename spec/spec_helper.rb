$: << File.join(File.dirname(__FILE__), '..', 'lib')
$: << File.join(File.dirname(__FILE__))
ENV['RACK_ENV'] = 'test'

require 'pry'
require 'pp'
require 'rspec'
require 'rack/test'
require 'webmock/rspec'
require 'support'

require 'coveralls'
Coveralls.wear!

RSpec.configure do |config|
	config.order = "random"
	config.color_enabled = true
end
