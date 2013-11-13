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
				:filters => {:match => 'magic'},
				:namespace => 'namespace'
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
				'"alias":"logstash-2013.08.02_baee106842'\
				'9a8e0b44179ca85b8d51bf3a10746d",'\
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
					"baee1068429a8e0b44179ca85b8d51bf3a"\
					"10746d/_search"
			).to_return(:status => 200, :body => "PONY LOGS")

			get('/logstash-2013.08.02/_search')
			expect(last_response.status).to eql(200)
			expect(last_response.body).to eql('PONY LOGS')
		end

		it 'makes safe a search on a protected indices' do
			# Should proxy a request to the alias created before
			stub_request(
				:get,
				"http://localhost:9200/"\
					"logstash-2013.08.02_"\
					"baee1068429a8e0b44179ca85b8d51bf3a"\
					"10746d"\
					",logstash-2013.08.03_"\
					"baee1068429a8e0b44179ca85b8d51bf3a"\
					"10746d"\
					"/_search"
			).to_return(:status => 200, :body => "PONY MULTI LOGS")

			get('/logstash-2013.08.02,logstash-2013.08.03/_search')
			expect(last_response.status).to eql(200)
			expect(last_response.body).to eql('PONY MULTI LOGS')
		end

		it 'makes private a put to dashboards' do
			stub_request(
				:put,
				"http://localhost:9200/kibana-int_"\
					"1963ebc61173a88a038513558"\
					"0dc1b7cd78e2c17/"\
					"dashboard/test"
			).to_return(:status => 200, :body => "YAY")

			put('/kibana-int/dashboard/test')
			expect(last_response.status).to eql(200)
			expect(last_response.body).to eql('YAY')
		end

		it 'allows POST /_nodes' do
			stub_request(
				:get,
				"http://localhost:9200/_nodes/"
			).to_return(:status => 200, :body => "nodes")


			expect(get('/_nodes/').status).
				to eql(200)
			expect(last_response.body).to eql('nodes')
		end

		it 'allows /_all/_mapping' do
			stub_request(
				:get,
				"http://localhost:9200/_all/_mapping/"
			).to_return(:status => 200, :body => "mapping")


			expect(get('/_all/_mapping/').status).
				to eql(200)
			expect(last_response.body).to eql('mapping')
		end
	end
end
