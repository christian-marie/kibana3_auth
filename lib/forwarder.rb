# Based on Rack::Forwarder, which no longer exists.

require 'net/http'
require 'rack'
 
class Forwarder
	def initialize(backend)
		@uri = URI(backend)
	end

	def perform_request(env)
		rackreq = Rack::Request.new(env)
		 
		headers = Rack::Utils::HeaderHash.new
		env.each do |key, value|
			if key =~ /HTTP_(.*)/
				headers[$1] = value
			end
		end
 
		res = Net::HTTP.start(@uri.host, @uri.port) do |http|
			m = rackreq.request_method
			case m
			when "GET", "HEAD", "DELETE", "OPTIONS", "TRACE"
				req = Net::HTTP.const_get(m.capitalize).new(
					rackreq.fullpath, headers
				)
			when "PUT", "POST"
				req = Net::HTTP.const_get(m.capitalize).new(
					rackreq.fullpath, headers
				)

				# No streaming for you!
				request_body = ''
				rackreq.body.each{|i| request_body += i}

				req.body = request_body
			else
				raise "method not supported: #{method}"
			end
			 
			http.request(req)
		end
		 
		[
			res.code,
			Rack::Utils::HeaderHash.new(res.to_hash),
			[res.body]
		]
	end
end
