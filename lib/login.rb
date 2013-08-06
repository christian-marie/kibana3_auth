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

	def configurable_login(user, pass)
		ret = @config[:login].call(user, pass)
		if ret.is_a?(Array) && ret.size != 2 then
			raise ::RuntimeError, 'Login method should return '\
				'an array of two elements, the user id '\
				'and the filters'
		end

		# If the login returned false or nil, pass that on now.
		return ret unless ret

		user_id, filters = ret
		@env['rack.session'][:user_id] = user_id
		@env['rack.session'][:filters] = filters
	end
end
