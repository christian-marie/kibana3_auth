require 'forwarder'
require 'json'
require 'digest/md5'

class ESProxy < Forwarder
	def initialize(config)
		super(config[:backend])
	end

	def call(env)
		@env = env 
		rewrite_env
		rewrite_response(perform_request(@env))
	end

	# If this is a response to an _aliases request, we need to create the
	# relevant safe aliases for this customer.
	def rewrite_response(response)
		if @env['ALIAS_REQUEST'] then 
			response[2] = create_aliases(response.last) 
		end

		response
	end

	# Make a request to the upstream ES server to create the filtered
	# aliases we need.
	def create_aliases(response_body)
		read_body = ''
		response_body.each{|i| read_body += i}

		actions = JSON.parse(read_body).map do |k,v|
			action = {
				'add' => {
					'index'  => k ,
					'alias'  => "#{k}_#{self.user_id}",
				}
			}
			unless self.filters == 'UNFILTERED' then
				action['add']['filter'] = self.filters
			end
			action
		end

		json = {:actions => actions}.to_json

		# Make the request
		Net::HTTP.start(@uri.host, @uri.port) do |http|
			post = Net::HTTP::Post.new('/_aliases', {})
			post.body = json
			http.request(post)
		end

		return [read_body]
	end

	def filters
		@env['rack.session'][:filters]
	end

	# Hash the filters so that we can reuse identical filters.
	def user_id
		Digest::MD5::hexdigest(self.filters.to_json)
	end

	# This is run before the request is sent upstream.
	#
	# We have to flag _aliases as a special request, so that we know to
	# create aliases from it when we get he response of all the aliases
	# later.
	#
	# We only allow _aliases and _search to be hit
	def rewrite_env
		request = Rack::Request.new(@env)

		case @env['PATH_INFO']
		when /^\/_aliases\/*?$/
			raise 'Must GET' unless request.get?
			# Flag the aliases to be requested when we make the
			# request later on
			@env['ALIAS_REQUEST'] = true
		when /^\/logstash-[\d\.]{10}\/_search\/*?$/
			# 
			rewrite_search_request
		else
			raise 'You should not be here, this is a bug'
		end
	end

	# Try to make a search safe, by inserting _customer_id before the
	# /_search in a string ending in /_search
	#
	# This means that the request will be for the filtered alias as opposed
	# to the actual index.
	def rewrite_search_request
		match = @env['PATH_INFO'] =~ /\/_search\z/
		raise "Couldn't make search safe, exploding" unless match

		@env['PATH_INFO'].insert(
			match,
			"_#{self.user_id}"
		)
	end
end
