require 'sinatra'
require 'oauth'
require 'trello'
require 'json'

include Trello
include Trello::Authorization

$stdout.sync = true

Trello::Authorization.const_set :AuthPolicy, OAuthPolicy

# [impact, effort]
CELL_LAYOUT = [["high",   "high"], ["high",   "medium"], ["high",   "low"],
               ["medium", "high"], ["medium", "medium"], ["medium", "low"],
               ["low",    "high"], ["low",    "medium"], ["low",    "low"]]

CALLBACK_PATH = "/auth/trello/callback"
OAuthPolicy.consumer_credential = OAuthCredential.new ENV['TRELLO_API_KEY'], ENV['TRELLO_OAUTH_SECRET']
CONSUMER = OAuth::Consumer.new(ENV['TRELLO_API_KEY'], ENV['TRELLO_OAUTH_SECRET'],
            {:scheme      => :header,
            :scope       => 'read,write',
            :http_method => :get,
            :request_token_path => "https://trello.com/1/OAuthGetRequestToken",
            :authorize_path     => "https://trello.com/1/OAuthAuthorizeToken",
            :access_token_path  => "https://trello.com/1/OAuthGetAccessToken"})

class Card < BasicData
  def cell
    self.actions.select {|a|
      a.type == "commentCard" 
    }.map {|c|
      [c.id, c.data["text"].match('(impact|effort)=(high|medium|low),\s?(impact|effort)=(high|medium|low)')]
    }.select {|id, m|
      !m.nil? && m.length == 5
    }.map {|id, m|
      {:id => id, m[1].to_sym => m[2], m[3].to_sym => m[4]}
    }.first rescue nil
  end
end

class MyApp < Sinatra::Application

  use Rack::Session::Cookie, :expire_after => (60 * 60 * 24 * 7)

  get "/auth/trello/callback" do
    session[:oauth_token] = params[:oauth_token]
    session[:oauth_verifier] = params[:oauth_verifier]
    session[:access_token] = session[:request_token].get_access_token({:oauth_verifier => session[:oauth_verifier]})
    OAuthPolicy.token = OAuthCredential.new session[:access_token], nil
    redirect "/"
  end

  get '/' do
    check_session
    @boards = Member.find("me").boards
    erb :boards
  end

  get '/boards/:id' do
    check_session
    @board = Board.find(params[:id])
    cards = @board.cards.map {|c| [c.cell, c] }
    @buckets = divide_cards(cards)
    erb :board
  end

  post '/boards/:board/cards/:card' do
    check_session
    impact = params[:impact]
    effort = params[:effort]
    card = params[:card]
    comment = params[:comment]
    Client.delete("/actions/#{comment}") unless comment.empty?
    new_comment = JSON.parse Client.post("/cards/#{card}/actions/comments", :text => "impact=#{impact},effort=#{effort}") unless impact.empty? && effort.empty?
    new_comment["id"] rescue ""
  end

protected
  def divide_cards(cards)
    buckets = initialize_buckets
    CELL_LAYOUT.each_with_index do |pair,index|
      impact, effort = pair
      cards.each do |cell, card|
        if cell then
          if cell[:impact] == impact && cell[:effort] == effort then
            buckets[(index+1).to_s.to_sym] << {:comment => cell[:id], :card => card}
          end
        end
      end
    end
    cards.each do |cell, card|
      unless cell then
        buckets[:'0'] << {:card => card}
      end
    end
    return buckets
  end

  def initialize_buckets
    hash = {}
    (0..9).to_a.each {|i| hash[i.to_s.to_sym] = [] }
    hash
  end

  def check_session
    if !session[:request_token] || !session[:access_token]
      request_token = CONSUMER.get_request_token({:oauth_callback => request.scheme + "://" + request.host_with_port + CALLBACK_PATH, :scope => "read,write", :name => "Risk-Reward", :expiration => "30days"})
      session[:request_token] = request_token
      redirect request_token.authorize_url({:oauth_callback => request.scheme + "://" + request.host_with_port + CALLBACK_PATH, :scope => "read,write", :name => "Risk-Reward", :expiration => "30days"})
    else
      puts "request token: #{session[:request_token].token} access_token: #{session[:access_token].token}"
      OAuthPolicy.token = OAuthCredential.new session[:access_token].token, nil
    end
  end
end

