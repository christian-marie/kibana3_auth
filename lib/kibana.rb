require 'rack'
require 'helpers'

class Kibana
	include Helpers

	def call(env)
		# Default to /index.html
		if env['PATH_INFO'].delete('/').empty? then
			env['PATH_INFO'] = '/index.html'
		end

		response = ::Rack::File.new('kibana').call(env)
		if env['PATH_INFO'] == '/index.html' then
			# Tack on our header to add a logout button
			status, headers, body = response
			# 304 means 304 for us too
			return response if status == 304

			html_header = html('kibana_header')

			new_body = ''
			body.each{|i| new_body += i}

			new_body.gsub!(/(<body.*?>)/, "#{$1}#{html_header}")

			headers['Content-Length'] = new_body.bytesize.to_s
			headers['Cache-Control'] = 'max-age=0, must-revalidate'
			response = status, headers, [new_body]
		end

		return response
	end
end
