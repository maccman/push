require 'rubygems'
require 'bundler'

Bundler.require
$: << settings.root

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/config_file'
require 'active_support/time'
require 'active_support/core_ext/string'
require 'active_support/json'

module StripePush
  autoload :User, 'app/models/user'
end

include StripePush

configure do
  MongoMapper.setup({
    'production'  => {'uri' => ENV['MONGOHQ_URL']},
    'development' => {'uri' => 'mongodb://localhost:27017/stripepush-development'}
  }, settings.environment.to_s)

  set :sessions,
      :httponly     => false,
      :secure       => false,
      :expire_after => 2.years.to_i

  set :show_exceptions, true

  set :erb, :escape_html => true
  set :session_secret,   ENV['SESSION_SECRET']
  set :secret_key,       ENV['SECRET_KEY']
  set :publishable_key,  ENV['PUBLISHABLE_KEY']
  set :client_id,        ENV['CLIENT_ID']
  set :protection, false

  set :certificate_path, "certs/#{settings.environment}.pem"

  use OmniAuth::Builder do
    provider :stripe_platform,
             settings.client_id,
             settings.secret_key,
             :scope => 'read_only'
  end

  set(:auth) do |*roles|
    condition do
      unless current_user?
        session[:back] = request.url if request.get?
        halt 401
      end
    end
  end
end

helpers do
  def current_user=(user)
    session[:user_id] = user && user.id
  end

  def current_user
    @current_user ||= begin
      user_id = session[:user_id]
      user_id && User.find(user_id)
    end
  end

  def current_user?
    !!session[:user_id]
  end
end

get '/auth' do
  session[:device_token] = params[:device_token]
  redirect '/auth/stripe_platform'
end

get '/auth/stripe_platform/callback' do
  self.current_user = User.from_auth!(request.env['omniauth.auth'])

  if session[:device_token]
    self.current_user.add_token!(session[:device_token])
  end

  redirect '/auth/complete'
end

get '/auth/complete', :auth => :user do
  200
end

delete '/auth', :auth => :user do
  if token = params[:device_token]
    current_user.remove_token!(token)
  end

  session.clear
  200
end

get '/user', :auth => :user, :provides => :json do
  current_user.to_json
end

put '/user', :auth => :user, :provides => :json do
  current_user.update_attributes!(params)
  current_user.to_json
end

post '/webhook' do
  data = JSON.parse(request.body.read, :symbolize_names => true)
  user = User.find_by_uid(data[:user_id])

  event = Stripe::Event.retrieve(data[:id], user.secret_key)
  user && user.notify_event!(event)

  200
end