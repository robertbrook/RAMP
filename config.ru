require 'rubygems'
require 'sinatra'
 
set :environment,  :production
disable :run

require 'app'

run Sinatra.application