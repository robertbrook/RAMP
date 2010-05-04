require 'rubygems'
require 'sinatra'
 
set :environment,  :production
disable :run

require 'server'

run Sinatra.application