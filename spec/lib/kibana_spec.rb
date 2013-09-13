require 'spec_helper'
require 'kibana'

describe ::Kibana do 
	include Rack::Test::Methods

	def app
		::Kibana.new
	end

	it 'returns kibana stuff on GET /'  do
		responses = ['/', '', '//', 'index.html'].map { |url|
			get(url)
		}

		# Should all be a 200 and the same
		responses.each do |r|
			expect(r.status).to eql(200)
			expect(r.body).to eql(responses.first.body)
			expect(r.headers).to include(
				'Cache-Control' => 'max-age=0, '\
					'must-revalidate'
			)
		end

		# Should have our header in it
		expect(responses.first.body).to include('/logout')
	end

	it 'returns 404 on non-existant' do
		expect(get('404').status).to eql(404)
	end
end
