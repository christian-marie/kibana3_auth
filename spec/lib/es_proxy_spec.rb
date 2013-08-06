require 'spec_helper'
require 'router'

describe ::ESProxy do 
	include Rack::Test::Methods
	include Support::Session

	def app
		@config ||= {
			:backend => 'http://localhost:9200'
		}
		::ESProxy.new(@config)
	end

	context 'with session' do
		before :each do
			@session = {
				:user_id => 'uid',
				:filters => {:match => 'magic'}
			}
		end

		# Test kibana rendering as it's a little method within the
		# router 
		it 'makes a request upstream on GET /_aliases'  do
			# We should hit upstream to fetch the current aliases,
			# so that we can make a subsequent request to create
			# filtered ones.
			upstream_response = \
				'{"logstash-2013.08.02":{"aliases":{}}}'
			stub_request(:get, "http://localhost:9200/_aliases").
				to_return(
					:status => 200,
					:body => upstream_response
				)
			# Here is the expected filter creation request.
			expected_request = '{"actions":'\
				'[{"add":{"index":"logstash-2013.08.02",'\
				'"alias":"logstash-2013.08.02_9871d3a2c5'\
				'54b27151cacf1422eec048",'\
				'"filter":{"match":"magic"}}}]}'
			stub_request(:post, "http://localhost:9200/_aliases").
				with(:body => expected_request)



			get('/_aliases')

			expect(last_response.status).to eql(200)
			expect(last_response.status).to eql(200)
		end

		it 'makes safe a search on a protected index' do
			# Should proxy a request to the alias created before
			stub_request(
				:get,
				"http://localhost:9200/logstash-2013.08.02_"\
					"9871d3a2c554b27151cacf1422eec048/"\
					"_search"
			).to_return(:status => 200, :body => "PONY LOGS")

			get('/logstash-2013.08.02/_search')
			expect(last_response.status).to eql(200)
			expect(last_response.body).to eql('PONY LOGS')
		end
	end
end
