# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'bcrypt'
require 'sanitize'
require 'sinatra/cookies'
require 'securerandom'
require 'digest'

require_relative 'db_persistance'

VISUAL_SECTIONS = %w[photos drawings].freeze
TEXT_SECTIONS = %w[blog_posts software_projects].freeze

POSTS_PER_PAGE = if Sinatra::Base.production?
                   10
                 else
                   2
                 end

configure do
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
  set :erb, escape_html: true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'db_persistance.rb'
end

before do
  @storage = DatabasePersistance.new(logger)
end

after do
  @storage.disconnect
end

helpers do
  def logged_in?
    session.key?(:email)
  end

  def post_body_preview(post)
    post.split("\n\n").each do |el|
      clean_el = Sanitize.fragment(el).strip
      return clean_el unless clean_el.empty?
    end
  end

  def tags_to_str(post)
    post[:tags].join(', ')
  end
end

not_found do
  page_does_not_exist
end

def redirect_if_logout
  return if logged_in?

  session[:error] = 'You must be signed in to do that.'
  redirect '/'
end

def redirect_if_loggedin
  redirect '/' if logged_in? && !auto_logged_in?
end

def error_valid_credentials(email, pwd)
  user_pw = @storage.get_user_password(email)
  msg = 'Please, enter valid credentials.'
  msg unless user_pw && (BCrypt::Password.new(user_pw) == pwd)
end

def login
  session.delete(:autolog)
  session[:email] = params[:user_email]
  handle_rememberme_feature
end

def encrypt_password(pwd)
  BCrypt::Password.create(pwd).to_s
end

def page_data
  @page_id = params[:page_id].to_i
  @tags_info = @storage.all_tags_for_post_type(params[:section])

  if params[:tag_id]
    page_data_by_pagetype_and_tag
  else
    page_data_by_pagetype
  end
end

def page_data_by_pagetype
  set_max_page_num
  redirect_if_page_num_not_in_range

  @posts = posts_for_page(params[:section], @page_id)
end

def page_data_by_pagetype_and_tag
  redirect_if_tag_does_not_exist

  set_max_page_num
  redirect_if_page_num_not_in_range

  @posts = posts_for_page(params[:section], @page_id, params[:tag_id])
end

def posts_for_page(post_type, page_id, tag_id = nil)
  offset = POSTS_PER_PAGE * page_id
  if tag_id
    @storage.posts_by_tag(post_type, tag_id, POSTS_PER_PAGE, offset)
  else
    @storage.posts(post_type, POSTS_PER_PAGE, offset)
  end
end

def set_max_page_num
  max_post_num = @storage.ntuple_posts(params[:section], params[:tag_id])
  max_page_num = (max_post_num.to_f / POSTS_PER_PAGE).ceil
  @max_page_num = max_page_num.zero? ? 1 : max_page_num
end

def redirect_if_page_num_not_in_range
  page_does_not_exist unless (0...@max_page_num).cover?(@page_id)
end

def redirect_if_tag_does_not_exist
  page_does_not_exist unless @tags_info.any? { |tag| tag[:id] == params[:tag_id] }
end

def redirect_if_post_not_exist
  page_does_not_exist unless valid_post_id?(params[:post_id])
end

def page_does_not_exist
  session[:error] = 'This page does not exist!'
  redirect '/'
end

def valid_post_id?(post_id)
  (post_id !~ /\D/) && @storage.post_exists?(post_id)
end

def error_new_pwd(pwd1, pwd2)
  if pwd1 != pwd2
    'Entered passwords do not match.'
  elsif pwd1.include?(' ')
    'Use of spaces in passwords is not allowed!'
  elsif pwd1.size < 4
    'The password must be 4 or more characters.'
  end
end

def categories_for_users
  @storage.all_categories.reject! { |i| i == 'about' }
end

def tags_to_arr
  params[:tags].to_s.strip.split(', ').sort
end

def auto_logged_in?
  session[:autolog]
end

def generate_token
  sel_n = 12
  val_n = 64
  { selector: SecureRandom.alphanumeric(sel_n),
    validator: SecureRandom.alphanumeric(val_n) }
end

def encode_token(token)
  { selector: token[:selector],
    validator: Digest::SHA256.hexdigest(token[:validator]) }
end

def parse_token_str(token_str)
  token_arr = token_str.split('-')
  { selector: token_arr[0], validator: token_arr[1] }
end

def token_valid?(received_token, stored_token)
  encode_token(received_token)[:validator] == stored_token[:validator]
end

def autologin_if_remembered_user
  autologin if remembered_user?
end

def autologin
  return if session[:email]

  selector = parse_token_str(cookies['remember_me_token'])[:selector]
  user_id = @storage.user_id_by_token_selector(selector)
  session[:email] = @storage.get_user_email(user_id)
  session[:autolog] = true
end

def remembered_user?
  return false unless request.cookies['remember_me_token']

  token = parse_token_str(request.cookies['remember_me_token'])
  db_token = @storage.find_token(token[:selector]) # should I delete this cookie if this does not stand?
  return false unless db_token

  return true if token_valid?(token, db_token)

  cookie_theft!(token)
end

def cookie_theft!(token)
  error_msg =
    'You are being a very bad person! This user is now logged out from all ' \
    'devices and the attemted theft is reported to the user!'

  session[:error] = error_msg
  user_id = @storage.user_id_by_token_selector(token[:selector])
  @storage.delete_all_user_tokens(user_id)
  redirect '/'
end

def set_remember_me_cookie
  rm_token = generate_token
  expiration_info = Time.now + (60 * 60 * 24 * 30)
  user_id = @storage.get_user_id_by_email(session[:email])
  response.set_cookie('remember_me_token', {
                        value: rm_token.values.join('-'),
                        expires: expiration_info
                      })
  @storage.new_token(encode_token(rm_token), user_id, expiration_info)
end

def force_resignin_if_autolog(redirect_back_path = nil)
  return unless session[:autolog]

  session[:redirect_location] = redirect_back_path
  session[:error] = 'Please, sign in again!'
  redirect '/signin'
end

def delete_remember_me_cookie
  token = parse_token_str(cookies['remember_me_token'])
  @storage.delete_token(token[:selector])
  cookies.delete('remember_me_token')
end

def handle_rememberme_feature
  delete_remember_me_cookie if request.cookies['remember_me_token']
  set_remember_me_cookie if params[:remember] == 'true'
end

def logout
  session.delete(:email)
  session.delete(:autolog)
  delete_remember_me_cookie if request.cookies['remember_me_token']
end
#============================= MAIN ============================================
# admin related features
# signin
get '/signin' do
  autologin_if_remembered_user
  redirect_if_loggedin

  erb :signin, layout: :layout
end

post '/signin' do
  autologin_if_remembered_user
  redirect_if_loggedin

  error = error_valid_credentials(params[:user_email], params[:password])
  if error
    session[:error] = error
    status 422
    erb :signin, layout: :layout
  else
    login
    session[:success] = 'Welcome!'
    redirect session.delete(:redirect_location) || '/'
  end
end

# signout
post '/signout' do
  autologin_if_remembered_user
  redirect_if_logout

  logout
  session[:success] = 'You have been signed out.'
  redirect '/'
end

# password change
get '/change_password' do
  autologin_if_remembered_user
  redirect_if_logout
  force_resignin_if_autolog(request.path_info)

  erb :pwd_change, layout: :layout
end

post '/change_password' do
  autologin_if_remembered_user
  redirect_if_logout
  force_resignin_if_autolog(request.path_info)

  new_pw1 = params[:password1]
  new_pw2 = params[:password2]

  error = (error_valid_credentials(session[:email], params[:password]) ||
           error_new_pwd(new_pw1, new_pw2))
  if error
    status 422
    session[:error] = error
    erb :pwd_change, layout: :layout
  else
    user_id = @storage.get_user_id_by_email(session[:email])
    @storage.delete_all_user_tokens(user_id)
    set_remember_me_cookie if request.cookies['remember_me_token']
    @storage.change_user_password(session[:email], encrypt_password(new_pw1))
    session[:success] = "You've successfully changed your password!"
    redirect '/'
  end
end

# create new post
get '/new' do
  autologin_if_remembered_user
  redirect_if_logout

  @categories = categories_for_users
  erb :new_page, layout: :layout
end

post '/new' do
  autologin_if_remembered_user
  redirect_if_logout

  category = params[:category]
  header = params[:header].strip
  body = params[:page_text]
  tags = tags_to_arr

  @storage.new_post(category, header, body, tags)

  new_post_id = @storage.latest_post_id

  session[:success] = 'The post has been created!'
  redirect "/posts/#{new_post_id}"
end

# edit existing post
get '/edit/1' do
  autologin_if_remembered_user
  redirect_if_logout
  force_resignin_if_autolog(request.path_info)

  @post = @storage.post_unrendered(1)
  @categories = [@post[:category]]
  params[:post_id] = '1'
  erb :edit, layout: :layout
end

get '/edit/:post_id' do
  autologin_if_remembered_user
  redirect_if_logout
  force_resignin_if_autolog(request.path_info)
  redirect_if_post_not_exist

  @post = @storage.post_unrendered(params[:post_id])
  @categories = [@post[:category]] + (categories_for_users - [@post[:category]])

  erb :edit, layout: :layout
end

post '/edit/:post_id' do
  autologin_if_remembered_user
  redirect_if_logout
  force_resignin_if_autolog(request.path_info)
  redirect_if_post_not_exist

  new_category = params[:category]
  new_header = params[:header].strip
  new_text = params[:page_text]
  new_tags = tags_to_arr

  post = @storage.post_unrendered(params[:post_id])

  if (post[:category] != new_category) ||
     (post[:header] != new_header) ||
     (post[:body] != new_text)
    @storage.update_post(params[:post_id], new_category, new_header, new_text)
  end

  @storage.update_post_tags(params[:post_id], new_tags) if post[:tags] != new_tags

  session[:success] = 'The post was sucessfully updated!'
  redirect "/posts/#{params[:post_id]}"
end

# delete existing post
post '/delete/:post_id' do
  autologin_if_remembered_user
  redirect_if_logout
  force_resignin_if_autolog("/posts/#{params[:post_id]}")
  redirect_if_post_not_exist

  @storage.delete_post(params[:post_id])
  session[:success] = 'The post was sucessfully deleted!'
  redirect '/'
end

# public pages
# index page
get '/' do
  autologin_if_remembered_user
  @about_post = @storage.about_page

  erb :index, layout: :layout
end

# visual post umbrella-page
get '/visualart/?' do
  autologin_if_remembered_user
  erb :visualart, layout: :layout
end

# generic post page
get '/posts/:post_id/?' do
  autologin_if_remembered_user
  redirect_if_post_not_exist

  @post = @storage.post(params[:post_id])
  erb :post_full_page, layout: :layout
end

# find on the web-site
get '/search' do
  autologin_if_remembered_user
  query = params[:query].to_s.strip
  @results = @storage.find_posts(query).reject { |p| p[:category] == 'about' }

  erb :search_results, layout: :layout
end

# existing sections pages
['/:section/tags/:tag_id/:page_id',
 '/:section/:page_id',
 '/:section/?'].each do |path|
  get path do
    autologin_if_remembered_user

    if VISUAL_SECTIONS.include?(params[:section])
      page_data
      erb :posts_feed_layout, locals: { section: params[:section] }, layout: :layout do
        erb :visual_posts
      end
    elsif TEXT_SECTIONS.include?(params[:section])
      page_data
      erb :posts_feed_layout, locals: { section: params[:section] }, layout: :layout do
        erb :text_posts
      end
    else
      page_does_not_exist
    end
  end
end
