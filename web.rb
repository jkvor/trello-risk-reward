require 'sinatra'
require 'redis'
require 'oa-openid'
require 'openid_redis_store'

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

protected
  def check_session
    if !session["authorized"]
      session["from"] = "/"
      redirect("/auth/google") 
    end
  end
end

