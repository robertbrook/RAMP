require 'rubygems'
require 'sinatra'
require 'json'
require 'haml'
require 'fastercsv'
require 'memcached'
require 'lib/MP'

enable :sessions

CACHE = Memcached.new

mp = MP.new("David Cameron", "Conservative", "Witney", "http://www.theyworkforyou.com/mp/david_cameron/witney")
CACHE.add("mp_test", mp.to_json)

MPS_DATA = File.new("./public/mps.csv").readlines
MAX_NUMBER = MPS_DATA.length - 1

get '/env' do
  "<code>" + ENV.inspect + "</code>"
end

get '/favicon.ico' do
  ""
end

get '/' do
  response = CACHE.get("mp_test")
  test = JSON.parse(response)
  "#{test['name']}, #{test['party']} MP for #{test['constituency']}<br />twfy_photo: #{test['twfy_photo']}<br />wikipedia_photo: #{test['wikipedia_photo']}"
end