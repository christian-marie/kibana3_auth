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
			expected_request = JSON.parse('{"actions":'\
				'[{"add":{"index":"logstash-2013.08.02",'\
				'"alias":"logstash-2013.08.02_f1ce5a347c'\
				'246197526e438fa58f3c7f",'\
				'"filter":{"match":"magic"}}}]}')
			stub_request(
				:post, "http://localhost:9200/_aliases"
			).with {|request|
				expect(JSON.parse(request.body)).
					to eql(expected_request)
			}

			get('/_aliases')

			expect(last_response.status).to eql(200)
			expect(last_response.status).to eql(200)
		end

		it 'makes safe a search on a protected index' do
			# Should proxy a request to the alias created before
			stub_request(
				:get,
				"http://localhost:9200/logstash-2013.08.02_"\
					"f1ce5a347c246197526e438fa58f3c7f/"\
					"_search"
			).to_return(:status => 200, :body => "PONY LOGS")

			get('/logstash-2013.08.02/_search')
			expect(last_response.status).to eql(200)
			expect(last_response.body).to eql('PONY LOGS')
		end

		it 'makes private a put to dashboards' do
			stub_request(
				:put,
				"http://localhost:9200/kibana-int_"\
					"f1ce5a347c246197526e438fa58f3c7f/"\
					"dashboard/test"
			).to_return(:status => 200, :body => "YAY")

			put('/kibana-int/dashboard/test')
			expect(last_response.status).to eql(200)
			expect(last_response.body).to eql('YAY')
		end
	end
end
