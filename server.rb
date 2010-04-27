require 'rubygems'
require 'sinatra'
require 'json'
require 'haml'
require 'lib/MP'

MPS_DATA = File.new("./public/mps.csv").readlines


get '/' do
  @number = params[:num].to_i
  unless @number
    @number = rand(642)+1
  end
  mp_data = MPS_DATA[@number]

  unless mp_data
    raise "#{@number}"
  end
  
  parts = mp_data.split(',')
  @random_mp = MP.new(parts[1..2].join(" ").squeeze(" "), parts[3], parts[4], parts[5])
  
  response = @random_mp.random_photo(3)["query"]
  if response
    @results_count = response["count"].to_i
  else
    @results_count = 0
  end
  
  if @results_count == 1
    @photos = [response["results"]["photo"]]
  end
  
  if @results_count > 1
    @photos = response["results"]["photo"]
  end

  haml :index
end



