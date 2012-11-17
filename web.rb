require 'sinatra'
require 'redis'
require 'oa-openid'
require 'openid_redis_store'
require 'trello'

include Trello
include Trello::Authorization

$stdout.sync = true

Trello::Authorization.const_set :AuthPolicy, OAuthPolicy
OAuthPolicy.consumer_credential = OAuthCredential.new ENV['TRELLO_API_KEY'], ENV['TRELLO_OAUTH_SECRET']
OAuthPolicy.token = OAuthCredential.new ENV['TRELLO_USER_KEY'], nil

class MyApp < Sinatra::Application

  use Rack::Session::Cookie, :secret => ENV["SECURE_KEY"], :expire_after => (60 * 60 * 24 * 7)
  use OmniAuth::Strategies::GoogleApps,
    OpenID::Store::Redis.new(Redis.connect(:url => ENV["REDISTOGO_URL"])),
    :name   => "google",
    :domain => "heroku.com"

  post "/auth/google/callback" do
    session["authorized"] = true
    redirect(session["from"] || "/")
  end

  get '/' do
    check_session
    "Hello, world"
  end

  get '/boards/:id' do
    check_session
    @board = Board.find(params[:id])
    @cards = @board.cards
    erb :board
  end

protected
  def check_session
    if !session["authorized"]
      session["from"] = "/"
      redirect("/auth/google") 
    end
  end
end

