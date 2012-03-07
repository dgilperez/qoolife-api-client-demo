require 'sinatra'
require 'sinatra/reloader'
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

  def authenticate!
    redirect to("/login") if !logged_in?
  end
end

before '/journal_entries*' do
  authenticate!
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
    api_query = RestClient::Resource.new("http://localhost:3000/api/v1/users/login", :user => params[:user_email], :password => params[:user_password])
    json_response = ActiveSupport::JSON.decode(api_query.get)
  rescue => ex
    logger.error "Exception at /login: #{ex.to_s}"
    redirect to("/login")
  end

  session[:user_email]      = params[:user_email]
  session[:user_password]   = params[:user_password]
  session[:user_first_name] = json_response['first_name']
  session[:user_last_name]  = json_response['last_name']

  redirect to("/")
end

get '/logout' do
  current_user = session[:user_email] = session[:user_password] = session[:user_first_name] = session[:user_last_name] = nil

  redirect to("/")
end

get '/journal_entries' do
  begin
    api_query = RestClient::Resource.new("http://localhost:3000/api/v1/journal_entries", :user => current_user[:email], :password => current_user[:password])
    json_response = ActiveSupport::JSON.decode(api_query.get)
  rescue => ex
    logger.error "Exception at /journal_entries: #{ex.to_s}"
    redirect to("/login")
  end

  @journal_entries = json_response.sort_by {|entry| Time.parse(entry['date'])}.reverse
  erb :journal_entries
end

post '/journal_entries' do
  begin
    resource = RestClient::Resource.new('http://localhost:3000/api/v1/journal_entries', :user => current_user[:email], :password => current_user[:password])
    resource.post(:journal_entry => {:body => params[:journal_entry_body], :private => params[:journal_entry_private], :date => Time.now})
  rescue => ex
    logger.error "Exception at /journal_entries: #{ex.to_s}"
  end

  redirect to("/journal_entries")
end

get '/journal_entries/new' do
  erb :journal_entries_new
end