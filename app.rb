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

# config_file 'config.yml'

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
      :httponly     => true,
      :secure       => production?,
      :expire_after => false

  set :show_exceptions, true

  set :erb, :escape_html => true
  set :session_secret,   ENV['SESSION_SECRET']
  set :secret_key,       ENV['SECRET_KEY']
  set :publishable_key,  ENV['PUBLISHABLE_KEY']
  set :client_id,        ENV['CLIENT_ID']
  set :protection, true

  set :certificate_path, "certs/#{settings.environment}.pem"

  use OmniAuth::Builder do
    provider :stripe_platform,
             settings.client_id,
             settings.secret_key,
             :scope => 'read_write'
  end
end

get '/auth' do
  session[:device_id] = params[:device_id]
  redirect '/auth/stripe_platform'
end

get '/auth/stripe_platform/callback' do
  user = User.from_auth!(request.env['omniauth.auth'])

  if session[:device_id]
    user.device_ids |= [session[:device_id]]
    user.save!
  end

  redirect '/auth/complete'
end

get '/auth/complete' do
  200
end

post '/webhook' do
  data  = JSON.parse(request.body.read, :symbolize_names => true)
  event = Stripe::Event.retrieve(data[:id], settings.secret_key)

  return unless event.type == 'charge.succeeded'

  user = User.find_by_uid(event.user_id)
  user && user.notify_charge(event.data.object)

  200
end