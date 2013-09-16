require 'helpers'

class Login
	include Helpers

	# For testing
	attr_reader :env

	def initialize(config)
		@config = config
	end

	def call(env)
		@env = env
		return case env['PATH_INFO']
		when %r{\A/login/*?\z}
			login
		when %r{\A/logout/*?\z}
			logout
		else
			raise('Request should NOT be here, this is a bug')
		end
	end

	def login
		request = Rack::Request.new(@env)
		response = Rack::Response.new

		# Already logged in, redirect to kibana
		if @env['rack.session'][:logged_in] then
			response.redirect('/')
			return response.finish
		end

		# Not logged in, send the form or do the login
		if request.post? then
			if configurable_login(
				request.params['user'],
				request.params['pass']
			) then
				# Success
				@env['rack.session'][:logged_in] =true
				response.redirect('/')
				return response.finish
			else
				# Failure
				response.body = [html('login_failure')]
				return response.finish
			end
		else
			response.body = [html('login')]
			return response.finish
		end
	end

	def logout
		@env['rack.session'].clear

		response = Rack::Response.new
		response.redirect('/login')
		response.finish
	end

	def default_namespace user, pass
		"#{user}#{pass}"
	end

	def configurable_login(user, pass)
		filters = @config[:login].call(user, pass)

		# Login failed
		return filters unless filters

		namespace_lambda = @config[:dashboard_namespace] \
			|| method(:default_namespace)

		@env['rack.session'][:filters] = filters
		@env['rack.session'][:namespace] = namespace_lambda.call(user,pass)
	end
end
