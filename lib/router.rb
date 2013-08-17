require 'rack'
require 'login'
require 'es_proxy'
require 'helpers'

class Router
	include Helpers

	# XXX Should be in the config
	LOGSTASH_INDEX = /logstash-[\d\.]{10}/

	# Evaluated in order, from top to bottom.
	URL_MAP = {
		%r{\A/(?:logout|login)/*?\z} => :upstream_login,
		%r{\A/_aliases/*?\z} => :upstream_elastic_search,
		%r{\A/#{LOGSTASH_INDEX}/_search/*?\z} => 
			:upstream_elastic_search,
		%r{\A/kibana-int/dashboard/\w+} =>
			:upstream_elastic_search,
		// => :upstream_kibana
	}

	attr_reader :upstream_kibana, :upstream_login, :upstream_elastic_search

	def initialize(config)
		@config = config

		@upstream_kibana = method(:serve_kibana)
		@upstream_login = Login.new(config)
		@upstream_elastic_search = ESProxy.new(config)
	end

	def call(env)
		# No access for you! Unless you have the secret session.
		# Or of course, you are asking for '/login', exactly.
		unless env['rack.session'][:logged_in] then
			if env['PATH_INFO'] == '/login'
				return self.upstream_login.call(env)
			end
			response = Rack::Response.new
			response.redirect('/login')
			return response.finish
		end


		URL_MAP.each do |pattern, sym|
			if env['PATH_INFO'] =~ pattern then
				# Stop at the first match
				return self.send(sym).call(env)
			end
		end
	end

	def serve_kibana env
		# Default to /index.html
		if env['PATH_INFO'].delete('/').empty? then
			env['PATH_INFO'] = '/index.html'
		end

		response = Rack::File.new('kibana').call(env)
		if env['PATH_INFO'] == '/index.html' then
			# Tack on our header to add a logout button
			status, headers, body = response
			# 304 means 304 for us too
			return response if status == 304

			header = html('kibana_header')

			new_body = ''
			body.each{|i| new_body += i}

			new_body.gsub!(/(<body.*?>)/, "#{$1}#{header}")

			headers['Content-Length'] = new_body.bytesize.to_s
			response = status, headers, [new_body]
		end

		return response
	end
end
