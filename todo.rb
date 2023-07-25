require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require 'pry'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

configure do
  set :erb, :escape_html => true
end

not_found do 
  redirect "/"
end 

helpers do 
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0 
  end 

  def todo_complete?(todo)
    todo[:completed]
  end 

  def list_class(list)
    "complete" if list_complete?(list)
  end 

  def todos_count(list)
    list[:todos].size
  end 

  def todos_remaining_count(list)
    list[:todos].select { |todo| !todo[:completed] }.size 
  end 

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition do |list|
      list_complete?(list)
    end 

    incomplete_lists.each { |list| yield(list, lists.index(list)) }
    complete_lists.each { |list| yield(list, lists.index(list)) }
  end 

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition do |todo|
      todo_complete?(todo)
    end 

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end 

  def next_todo_id(todos)
    if todos.empty?
      return 1
    else
      ids = todos.map { |todo| todo[:id] }
      max_id = ids.max
      return max_id + 1
    end
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

def load_list(index)
  list = session[:lists][index] if index && session[:lists][index]
  return list if list 

  session[:error] = "The specified list was not found."
  redirect "/lists"
end 

# View list of all lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !name.size.between?(1, 100)
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

def error_for_todo(name)
  if !name.size.between?(1, 100)
    "Todo must be between 1 and 100 characters."
  end 
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View Single List
get "/lists/:id" do 
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end 

# Edit Existing List 
get "/lists/:id/edit" do
  @id = params[:id].to_i
  @list = load_list(@id)
  erb :edit_list, layout: :layout
end 

# Update Existing List
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end 

# Delete Single List from Lists array
def delete_list(lists, id)
  lists.delete_at(id)
end

# Delete list
post "/lists/:id/delete" do 
  @lists = session[:lists]
  @id = params[:id].to_i
  
  delete_list(@lists, @id)

  if env["HTTP_X_REQUESTED_WITH"] = "XMLHttpRequest"
    "/lists"
  else 
    session[:success] = "List Removed"
    redirect "/lists"
  end 
end 

# Add a new todo to list
post "/lists/:list_id/todos" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip 

  error = error_for_todo(text)
  if error 
    session[:error] = error
    erb :list, layout: :layout 
  else 
    todo_id = next_todo_id(@list[:todos])
    @list[:todos] << {id: todo_id, name: text, completed: false}
    session[:success] = "The todo was added to the list."
    redirect "/lists/#{@list_id}"
  end 
end 

# Delete todo item from list 
post "/lists/:list_id/todos/:id/delete" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  
  @list[:todos].reject! { |todo| todo[:id] == todo_id } 

  if env["HTTP_X_REQUESTED_WITH"] = "XMLHttpRequest"
    status 204
  else 
    session[:success] = "Todo Removed"
    redirect "/lists/#{@list_id}"
  end 
end 

# Update the status of a todo 
post "/lists/:list_id/todos/:id" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  
  todo = @list[:todos].find { |todo| todo[:id] == todo_id } 

  todo[:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos complete for single list
post "/lists/:list_id/complete_all" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @list[:todos].each { |todo| todo[:completed] = true }

  session[:success] = "All todos marked 'complete'."
  redirect "/lists/#{@list_id}"
end 
