require 'spec_helper'
require 'router'

describe ::Login do 
	include Rack::Test::Methods
	include Support::Session

	def app
		@config ||= {}
		@app = ::Login.new(@config)
	end

	shared_examples 'logs out' do
		it 'logs out on get /logout' do
			fake_session = double('fake session')
			fake_session.should_receive(:clear)

			get('/logout', {}, {'rack.session' => fake_session})
		end
	end

	context 'with session' do
		before :each do
			@session = {:logged_in => true}
		end

		include_examples 'logs out'

		it 'redirects to / on get /' do
			expect(get('/login/')).
				to be_redirect
			expect(last_response.headers).to eql(
				'Location' => '/'
			)
		end
	end

	context 'without session' do
		include_examples 'logs out'

		it 'sends login page on get /' do
			get('/login')
			expect(last_response.body).to include('html')
		end

		it 'logs in on post /login with good credentioals' do
			Login.any_instance.should_receive(:configurable_login).
				with('dude', 'man').
				and_return(true)
			post(
				'/login',
				{
					:user => 'dude',
					:pass => 'man'
				}
			)

			expect(last_response.status).to eql(302)
			expect(@app.env['rack.session']).to be_true
		end

		it 'does not log in on post /login' do
			Login.any_instance.should_receive(:configurable_login).
				with('dude', 'man').
				and_return(false)
			post(
				'/login',
				{
					:user => 'dude',
					:pass => 'man'
				}
			)

			expect(@app.env['rack.session'][:logged_in]).
				to be_false
		end

		it 'should try the login from the config' do
			@config = {
				:login => lambda do |user, pass|
					expect(user).to eql('1')
					expect(pass).to eql('2')
					'filters'
				end
			}

			post(
				'/login',
				{
					:user => '1',
					:pass => '2'
				}
			)

			expect(@app.env['rack.session']).to eql({
				:filters   => "filters",
				:logged_in => true,
				:namespace => "12",
			})
		end

		it 'should try the optional namespace method' do
			@config = {
				:login => Proc.new {1},
				:dashboard_namespace => lambda { |u, p| "#{p}#{u}" },
			}

			post(
				'/login',
				{
					:user => '1',
					:pass => '2',
				}
			)

			expect(@app.env['rack.session']).to eql({
				:filters   => 1,
				:logged_in => true,
				:namespace => "21",
			})
		end
	end
end
