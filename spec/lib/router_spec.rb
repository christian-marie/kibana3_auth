require 'spec_helper'
require 'router'

describe ::Router do 
	include Rack::Test::Methods
	include Support::Session

	def app
		@config ||= {
			:backend => 'http://localhost:9200'
		}
		::Router.new(@config)
	end

	context 'with session' do
		before :each do
			@session =  {:logged_in => true}
		end

		it 'returns 404 on non-existant' do
			expect(get('404').status).to eql(404)
		end

		it 'hits elasticsearch on _aliases' do
			::ESProxy.any_instance.should_receive(:call).
				and_return([200, {}, ['hai']])
			expect(get('/_aliases/').status).to eql(200)
			expect(last_response.body).to eql('hai')
		end

		it 'hits elasticsearch on _search' do
			::ESProxy.any_instance.should_receive(:call).
				and_return([200, {}, ['hai']])
			expect(get('/logstash-2013.07.30/_search/').status).
				to eql(200)
			expect(last_response.body).to eql('hai')
		end

		it 'hits elasticsearch on /kibana-int/dashboard/foo' do
			::ESProxy.any_instance.should_receive(:call).
				and_return([200, {}, ['hai']])
			expect(post('/kibana-int/dashboard/foo/').status).
				to eql(200)
			expect(last_response.body).to eql('hai')
		end

		it 'routes to logout' do
			::Login.any_instance.should_receive(:call).
				and_return([200, {}, ['logout']])

			get '/logout'
			expect(last_response.status).to eql(200)
			expect(last_response.body).to eql('logout')
		end
	end

	context 'without session' do
		it 'redirects to /login' do
			get '/'

			expect(last_response).to be_redirect
			expect(last_response.headers).to eql(
				'Location' => '/login'
			)
		end

		it 'displays /login' do
			::Login.any_instance.should_receive(:call).
				and_return([200, {}, ['hai']])

			get '/login'
			expect(last_response.status).to eql(200)
			expect(last_response.body).to eql('hai')
		end
	end
end
