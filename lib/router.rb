require 'rack'
require 'login'
require 'es_proxy'
require 'kibana'

class Router
	include Helpers

	LOGSTASH_INDEX = %r{(logstash-[\d\.]{10})}
	SEARCH_PATH    = %r{\A/(?:#{LOGSTASH_INDEX},?)+/_search/*?\z}
	ALIASES_PATH   = %r{\A/(?:#{LOGSTASH_INDEX},?)+/_aliases\z}

	# Evaluated in order, from top to bottom.
	URL_MAP = [
		[%r{\A/(?:logout|login)/*?\z}    , :upstream_login ]         ,
		[%r{\A/_aliases/*?\z}            , :upstream_elastic_search] ,
		[%r{\A/[^/]*/_mapping/*?\z}      , :upstream_elastic_search] ,
		[%r{\A/_nodes/?\z}               , :upstream_elastic_search] ,
		[SEARCH_PATH                     , :upstream_elastic_search] ,
		[ALIASES_PATH                    , :upstream_elastic_search] ,
		[%r{\A/kibana-int/dashboard/}    , :upstream_elastic_search] ,
		[//                              , :upstream_kibana]         ,
	]

	attr_reader :upstream_kibana, :upstream_login, :upstream_elastic_search

	def initialize(config)
		@config = config

		@upstream_kibana = ::Kibana.new
		@upstream_login = ::Login.new(config)
		@upstream_elastic_search = ::ESProxy.new(config)
	end

	def call(env)
		# No access for you! Unless you have the secret session.
		# Or of course, you are asking for '/login', exactly.
		unless env['rack.session'][:logged_in] then
			if env['PATH_INFO'] == '/login'
				return self.upstream_login.call(env)
			end
			response = ::Rack::Response.new
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
end
