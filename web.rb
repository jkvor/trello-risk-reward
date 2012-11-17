require 'sinatra'
require 'redis'
require 'oa-openid'
require 'openid_redis_store'
require 'trello'
require 'json'

include Trello
include Trello::Authorization

$stdout.sync = true

Trello::Authorization.const_set :AuthPolicy, OAuthPolicy
OAuthPolicy.consumer_credential = OAuthCredential.new ENV['TRELLO_API_KEY'], ENV['TRELLO_OAUTH_SECRET']
OAuthPolicy.token = OAuthCredential.new ENV['TRELLO_USER_KEY'], nil

class Card < BasicData
  def cell
    self.actions.select {|a|
      a.type == "commentCard" 
    }.map {|c|
      c.data["text"].match('(impact|effort)=(high|medium|low),\s?(impact|effort)=(high|medium|low)')
    }.select {|m|
      !m.nil? && m.length == 5
    }.map {|m|
      {m[1].to_sym => m[2], m[3].to_sym => m[4]}
    }.first rescue nil
  end
end

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
    #check_session
    @board = Board.find(params[:id])
    cards = @board.cards.map {|c| [c.cell, c] }
    @buckets = divide_cards(cards)
    erb :board
  end

protected
  def divide_cards(cards)
    buckets = initialize_buckets
    # [impact, effort]
    layout = [["high",   "high"], ["high",   "medium"], ["high",   "low"],
              ["medium", "high"], ["medium", "medium"], ["medium", "low"],
              ["low",    "high"], ["low",    "medium"], ["low",    "low"]]
    layout.each_with_index do |pair,index|
      impact, effort = pair
      cards.each do |cell, card|
        if cell then
          if cell[:impact] == impact && cell[:effort] == effort then
            buckets[(index+1).to_s.to_sym] << card
          end
        end
      end
    end
    cards.each do |cell, card|
      unless cell then
        buckets[:'0'] << card
      end
    end
    return buckets
  end

  def initialize_buckets
    {:'1' => [],
     :'2' => [],
     :'3' => [],
     :'4' => [],
     :'5' => [],
     :'6' => [],
     :'7' => [],
     :'8' => [],
     :'9' => [],
     :'0' => []}
  end

  def check_session
    if !session["authorized"]
      session["from"] = "/"
      redirect("/auth/google") 
    end
  end
end

