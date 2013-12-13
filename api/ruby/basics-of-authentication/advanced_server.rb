require 'sinatra'
require 'rest_client'
require 'json'

# !!! DO NOT EVER USE HARD-CODED VALUES IN A REAL APP !!!
# Instead, set and test environment variables, like below
# if ENV['GITHUB_CLIENT_ID'] && ENV['GITHUB_CLIENT_SECRET']
#  CLIENT_ID        = ENV['GITHUB_CLIENT_ID']
#  CLIENT_SECRET    = ENV['GITHUB_CLIENT_SECRET']
# end

CLIENT_ID = ENV['GH_BASIC_CLIENT_ID']
CLIENT_SECRET = ENV['GH_BASIC_SECRET_ID']

use Rack::Session::Cookie, :secret => rand.to_s()

def authenticated?
  puts session[:access_token]
  session[:access_token]
end

def authenticate!
  erb :index, :locals => {:client_id => CLIENT_ID}
end

get '/' do
  if !authenticated?
    authenticate!
  else
    access_token = session[:access_token]
    scopes = session[:scopes]

    auth_result = JSON.parse(RestClient.get("https://api.github.com/user",
                                            {:params => {:access_token => access_token},
                                             :accept => :json}))

    if scopes.include? 'user:email'
      auth_result['private_emails'] =
        JSON.parse(RestClient.get("https://api.github.com/user/emails",
                                  {:params => {:access_token => access_token},
                                   :accept => :json}))
    end

    erb :advanced, :locals => {:login => auth_result["login"],
                               :public_email => auth_result["email"],
                               :private_emails => auth_result["private_emails"]}
  end
end

get '/callback' do
  session_code = request.env['rack.request.query_hash']["code"]

  result = RestClient.post("https://github.com/login/oauth/access_token",
                          {:client_id => CLIENT_ID,
                           :client_secret => CLIENT_SECRET,
                           :code => session_code},
                           :accept => :json)

  session[:access_token] = JSON.parse(result)["access_token"]
  session[:scopes] = JSON.parse(result)["scope"].split(",")

  redirect '/'
end