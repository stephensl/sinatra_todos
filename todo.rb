require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

configure do 
  enable :session
  set :session_secret, "628141d15b5c99de6aac2aef1a7b96b25ca8dfb8d4e20f0d9a22db037e245596"
end 

#set :session_secret, SecureRandom.hex(32)

before do 
  session[:lists] ||= []
end 

get "/" do 
  redirect "/lists"
end 

get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

get "/lists/new" do 
  session[:lists] << { name: "New List", todos: [] }
  redirect "/lists"
end 


