require 'rubygems'
require 'sinatra'
require 'json'
require 'haml'
require 'fastercsv'
require 'memcached'
require 'lib/MP'

enable :sessions

CACHE = Memcached.new

MPS_DATA = File.new("./public/mps.csv").readlines
MAX_NUMBER = MPS_DATA.length - 1

get '/env' do
  "<code>" + ENV.inspect + "</code>"
end

get '/favicon.ico' do
  ""
end

get '/' do
  session[:attempts] = 0 unless session[:attempts]
  session[:correct] = 0 unless session[:correct]
  session[:wrong] = 0 unless session[:wrong]
  
  begin
    response = CACHE.get("mp_test")
  rescue
    mp = MP.new("David Cameron", "Conservative", "Witney", "http://www.theyworkforyou.com/mp/david_cameron/witney", 96)
    json = mp.to_json
    CACHE.add("mp_test", json)
    response = json
  end
  @mp = JSON.parse(response)
  haml :vcard
end