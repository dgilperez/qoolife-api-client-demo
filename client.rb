require 'sinatra'
require 'sinatra/reloader'
require 'open-uri'
require 'rest-client'
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
      :last_name  => session[:user_last_name],
      :name       => "#{session[:user_first_name]} #{session[:user_last_name]}"
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
  current_user = session[:user_email] = session[:user_password] = session[:user_first_name] = session[:user_last_name] = nil

  redirect to("/")
end

get '/journal_entries' do
  if !logged_in?
    redirect to("/login")
  else
    begin
      api_query = open("http://localhost:3000/api/v1/journal_entries", :http_basic_authentication => [current_user[:email], current_user[:password]])
    rescue OpenURI::HTTPError => ex
      logger.error "Exception at /journal_entries: #{ex.to_s}"
      redirect to("/login")
    end

    if api_query.status[0] == "200"
      json_response = ActiveSupport::JSON.decode(api_query.read)
      @journal_entries = json_response.sort_by {|entry| Time.parse(entry['date'])}.reverse
      erb :journal_entries
    else
      redirect to("/login")
    end
  end
end

post '/journal_entries' do
  if !logged_in?
    redirect to("/login")
  else
    begin
      resource = RestClient::Resource.new('http://localhost:3000/api/v1/journal_entries', :user => current_user[:email], :password => current_user[:password])
      resource.post(:journal_entry => {:body => params[:journal_entry_body], :private => params[:journal_entry_private], :date => Time.now})
    rescue => ex
      logger.error "Exception at /journal_entries: #{ex.to_s}"
    end

    redirect to("/journal_entries")
  end
end

get '/journal_entries/new' do
  if !logged_in?
    redirect to("/login")
  else
    erb :journal_entries_new
  end
end