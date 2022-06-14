# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'

require_relative '../ccw'

class MahnoTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env['rack.session']
  end

  def user_session
    { 'rack.session' => { email: 'vysh@gmail.com' } }
  end

  def teardown
    system('dropdb mywebsite')
    system('createdb mywebsite')
    system('psql -d mywebsite < scheme.sql')
  end

  def test_main
    get '/'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<a href="/">Main</a>'
    assert_includes last_response.body, '<a href="/visualart">Visual Art</a>'
    assert_includes last_response.body, '<a href="/blog_posts/0">Writings</a>'
    assert_includes last_response.body, '<a href="/software_projects/0">Software Projects</a>'
    assert_includes last_response.body, '<h2>Hello and Welcome to my web-site!'
    assert_includes last_response.body, '<a href="/signin">Sign In'
    refute_includes last_response.body, '<a href="/edit/1">'

    get '/', {}, user_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Signed in with email: vysh@gmail.com'
    assert_includes last_response.body, '<button type="submit">Sign Out</button>'
    assert_includes last_response.body, '<a href="/edit/1">'
  end

  def test_signin_page
    get '/signin'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, "<input type='email' name='user_email' id='user_email' "
    assert_includes last_response.body, "<input type='password' name='password' id='password' >"

    get '/signin', {}, user_session
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_includes last_response.body, 'Welcome to my web-site'
  end

  def test_invalid_signin
    post '/signin', user_email: '  ', password: '1234'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please, enter valid credentials.'
    assert_nil session[:email]

    post '/signin', user_email: 'vysh@gmail.com', password: 'mmm'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please, enter valid credentials.'
    assert_nil session[:email]

    post '/signin', user_email: 'wrong@gmail.com', password: '1234'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please, enter valid credentials.'
    assert_nil session[:email]

    post '/signin', user_email: 'wrong@gmail.com', password: 'wrong_pass'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please, enter valid credentials.'
    assert_nil session[:email]
  end

  def test_valid_signin
    post '/signin', user_email: 'vysh@gmail.com', password: '1234'
    assert_equal 302, last_response.status
    assert_equal 'vysh@gmail.com', session[:email]
    assert_equal 'Welcome!', session[:success]

    get '/'
    assert_includes last_response.body, 'Signed in with email: vysh@gmail.com'
  end

  def test_signout
    get '/', {}, user_session
    assert_includes last_response.body, 'Signed in with email: vysh@gmail.com'

    post '/signout'
    assert_equal 302, last_response.status
    assert_nil session[:email]
    assert_equal 'You have been signed out.', session[:success]

    get last_response['Location']
    assert_includes last_response.body, 'Sign In'
  end

  def test_visual_art
    get '/visualart'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<a href="/drawings/0">'
    assert_includes last_response.body, '<a href="/photos/0"'
    refute_includes last_response.body, '><</a>'
    refute_includes last_response.body, 'Page'
  end

  def test_drawings
    get '/drawings/0'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h3>Not my drawing'
    assert_includes last_response.body, '<p><em>Date: </em> 2022-'
    assert_includes last_response.body, '<a href="/drawings/tags/3/0">art'
    assert_includes last_response.body, 'Page 1'
    assert_includes last_response.body, '<p><em>Tags: </em> art, work of others'
    refute_includes last_response.body, '><</a>'
  end

  def test_photos
    get '/photos/0'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h3>Flowers'
    assert_includes last_response.body, '<p><em>Date: </em> 2022-'
    assert_includes last_response.body, '<a href="/photos/tags/1/0">my life'
    assert_includes last_response.body, 'Page 1'
    assert_includes last_response.body, '<p><em>Tags: </em> my life, nature'
    refute_includes last_response.body, '><</a>'
  end

  def test_writings
    get '/blog_posts/0'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h3>Post number 5'
    assert_includes last_response.body, '<p><em>Date: </em> 2022-'
    assert_includes last_response.body, '<a href="/blog_posts/tags/3/0">art'
    assert_includes last_response.body, 'Page 1'
    assert_includes last_response.body, '<p><em>Tags: </em> my life'
    assert_includes last_response.body, '<a href="/blog_posts/1">></a>'
  end

  def test_software_projects
    get '/software_projects'
    assert_equal 200, last_response.status
    get '/software_projects/'
    assert_equal 200, last_response.status

    get '/software_projects/0'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h3>Stus'
    assert_includes last_response.body, '<p><em>Date: </em> 2022-'
    assert_includes last_response.body, '<a href="/software_projects/tags/5/0">helping others'
    assert_includes last_response.body, 'Page 1'
    assert_includes last_response.body, '<p><em>Tags: </em> helping others'
    refute_includes last_response.body, '">></a>'
  end

  def test_pagination_on_writings
    get '/blog_posts/1'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h3>Sanitization test'
    assert_includes last_response.body, '<p><em>Date: </em> 2022-'
    assert_includes last_response.body, '<a href="/blog_posts/tags/3/0">art'
    assert_includes last_response.body, 'Page 2'
    assert_includes last_response.body, '<p><em>Tags: </em> my life'
    assert_includes last_response.body, '<a href="/blog_posts/2">></a>'
  end

  def test_filter_on_writings
    get '/blog_posts/tags/1/0'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h3>Post number 5'
    assert_includes last_response.body, 'Page 1'
    assert_includes last_response.body, '<a href="/blog_posts/tags/1/1">></a>'
    refute_includes last_response.body, '<h3>Flowers'

    get '/blog_posts/tags/1/2'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h3>Post number 1'
    assert_includes last_response.body, 'Page 3'
    refute_includes last_response.body, '">></a>'
    refute_includes last_response.body, '<h3>Flowers'
  end

  def test_non_existent_pages
    # general page does not exist
    get '/somethingelse'
    assert_equal 302, last_response.status
    assert_equal 'This page does not exist!', session[:error]

    # post does not exist
    get '/posts/12'
    assert_equal 302, last_response.status
    assert_equal 'This page does not exist!', session[:error]

    # page of posts does not exist
    get '/blog_posts/123456'
    assert_equal 302, last_response.status
    assert_equal 'This page does not exist!', session[:error]

    # filter does not exist
    get '/blog_posts/tags/12/0'
    assert_equal 302, last_response.status
    assert_equal 'This page does not exist!', session[:error]
  end

  def test_single_post
    get '/posts/8'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h3>Sanitization test'
    assert_includes last_response.body, '<img src="'
    assert_includes last_response.body, 'they desired nothing better than to meet the unicorn, to harpoon it'
    refute_includes last_response.body, 'Page'
    refute_includes last_response.body, '<a href="/edit/8'
    refute_includes last_response.body, "<form method='post' action='/delete/8"

    get '/posts/8', {}, user_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<a href="/edit/8'
    assert_includes last_response.body, "<form method='post' action='/delete/8"
  end

  def test_create_new_post
    # not signed in
    post '/new'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    # signed in
    post '/new', { category: 'post', header: 'this is new test post', page_text: 'sdfsdst' }, user_session
    assert_equal 302, last_response.status
    assert_equal 'The post has been created!', session[:success]

    get '/posts/12'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h3>this is new test post'
    assert_includes last_response.body, 'sdfsdst'
  end

  def test_create_new_post_page
    get '/new'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    get '/new', {}, user_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'Post text:'
    assert_includes last_response.body, '<input type="submit"'
    assert_includes last_response.body, '<select type="text" id="category" name="category"/>'
  end

  def test_edit_post_page
    get '/edit/1'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    get '/edit/1', {}, user_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body,
                    '<input type="text"id="header" name="header" value="Hello and Welcome to my web-site!"'
    assert_includes last_response.body, '<img style="float:left; padding-right:25px" '
    assert_includes last_response.body, '<option value=about>about</option>'
  end

  def test_edit_existing_post
    # access not logged in
    post '/edit/11',  { category: 'about', header: 'this is new header', page_text: 'Slava Ukraini!' }
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    # log in first
    post '/edit/11',
         { category: 'drawing', header: 'this is new header', page_text: 'Slava Ukraini!', tags: 'tag1, tag2' }, user_session
    assert_equal 302, last_response.status

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h3>this is new header'
    assert_includes last_response.body, 'Slava Ukraini!'
    assert_includes last_response.body, '<em>Tags: </em> tag1, tag2'
  end

  def test_delete_post
    # access not logged in
    post '/delete/11'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    post '/delete/11', {}, user_session
    assert_equal 302, last_response.status
    assert_equal 'The post was sucessfully deleted!', session[:success]

    get '/posts/11'
    assert_equal 302, last_response.status
    assert_equal 'This page does not exist!', session[:error]
  end

  def test_writings_preview_post
    get '/blog_posts/1'
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h3>Sanitization test'
    refute_includes last_response.body, '<img src="'
    refute_includes last_response.body, 'they desired nothing better than to meet the unicorn, to harpoon it'
  end

  def test_search
    get '/search', { query: '' }
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h3>20,000'
    refute_includes last_response.body, " As to the ship's company,"
    assert_includes last_response.body, '<img src="https://live.staticflickr.com/65535/52099970287_88d68859ca_k.jpg"'
  end

  def test_change_pass_page
    get '/change_password'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    get '/change_password', {}, user_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h2>Change password.</h2>'
    assert_includes last_response.body, '<input type="password" name="password" id="password"'
  end

  def test_change_password
    post '/change_password'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:error]

    # login
    post '/signin', user_email: 'vysh@gmail.com', password: '1234'

    # change password - wrong current password
    post '/change_password', password: '1234abcd', password1: '123456', password2: '123456'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Please, enter valid credentials.'

    # change pwd - not equal pswds
    post '/change_password', password: '1234', password1: '123456', password2: '1234567'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Entered passwords do not match.'

    # change pwd - too short pswds
    post '/change_password', password: '1234', password1: '1', password2: '1'
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'The password must be 4 or more characters.'

    # change password succesfully
    post '/change_password', password: '1234', password1: '12345', password2: '12345'
    assert_equal 302, last_response.status
    assert_equal "You've successfully changed your password!", session[:success]

    get last_response['Location']
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'My name is Dariia'

    # logout
    post '/signout'
    assert_equal 302, last_response.status
    assert_nil session[:email]
    assert_equal 'You have been signed out.', session[:success]

    # login with new Credentials
    post '/signin', user_email: 'vysh@gmail.com', password: '12345'
    assert_equal 302, last_response.status
    assert_equal 'vysh@gmail.com', session[:email]
    assert_equal 'Welcome!', session[:success]
  end
end
