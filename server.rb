require 'rubygems'
require 'sinatra'
require 'json'
require 'haml'
require 'fastercsv'
require 'lib/MP'

enable :sessions

MPS_DATA = File.new("./public/mps.csv").readlines


get '/' do
  last_number = session[:num]
  
  @number = params[:num]
  unless @number
    @number = rand(642)+1
    while last_number == @number
      @number = rand(642)+1
    end
  else
    @number = @number.to_i
  end
  
  session[:num] = @number
  
  data_line = MPS_DATA[@number]
  
  unless data_line
    raise "#{@number}"
  end
  
  mp_data = FasterCSV::parse_line(data_line)
  
  @random_mp = MP.new(mp_data[1..2].join(" ").squeeze(" "), mp_data[3], mp_data[4], mp_data[5])
  
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