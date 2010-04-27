require 'rubygems'
require 'sinatra'
require 'json'
require 'haml'
require 'lib/MP'

MPS_DATA = File.new("./public/mps.csv").readlines


get '/' do
  random_number = rand(642)+1
  mp_data = MPS_DATA[random_number]

  unless mp_data
    raise "#{random_number}"
  end
  
  parts = mp_data.split(',')
  @random_mp = MP.new(parts[1..2].join(" ").squeeze(" "), parts[3], parts[4], parts[5])
  
  response = @random_mp.random_photo(3)["query"]
  @results_count = response["count"].to_i
  
  if @results_count == 1
    @photos = [response["results"]["photo"]]
  end
  
  if @results_count > 1
    @photos = response["results"]["photo"]
  end

  haml :index
end



