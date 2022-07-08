require './ccw'
require 'rack/protection'

use Rack::Protection
run Sinatra::Application
