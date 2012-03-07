require 'sinatra'
require 'sinatra/reloader'
require 'open-uri'
require 'active_support'

enable :sessions

helpers do
  def logged_in?
    !session[:user_email].nil?
  end

  def current_user
    {
      :email      => session[:user_email],
      :password   => session[:user_password],
      :first_name => session[:user_first_name],
      :last_name  => session[:user_last_name]
    }
  end
end

get '/' do
  erb :home
end

get '/login' do
  if logged_in?
    redirect to("/")
  else
    erb :login
  end
end

post '/login' do
  begin
    api_query = open("http://localhost:3000/api/v1/users/login", :http_basic_authentication => [params[:user_email], params[:user_password]])
  rescue OpenURI::HTTPError => ex
    logger.error "Exception at /login: #{ex.to_s}"
  end

  if api_query && api_query.status[0] == "200"
    json_response = ActiveSupport::JSON.decode(api_query.read)

    session[:user_email]      = params[:user_email]
    session[:user_password]   = params[:user_password]
    session[:user_first_name] = json_response['first_name']
    session[:user_last_name]  = json_response['last_name']

    redirect to("/")
  else
    redirect to("/login")
  end
end

get '/logout' do
  session[:user_email] = session[:user_password] = session[:first_name] = session[:last_name] = nil

  redirect to("/")
end
