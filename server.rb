require 'rubygems'
require 'sinatra'
require 'json'
require 'haml'
require 'fastercsv'
require 'lib/MP'

enable :sessions

MPS_DATA = File.new("./public/mps.csv").readlines
MAX_NUMBER = MPS_DATA.length - 2

get '/' do
  last_number = session[:num]

  @number = params[:num]
  if @number
    @number = @number.to_i
  else
    @number = random_number(last_number)
  end
  
  session[:num] = @number
  
  @random_mp = setup_mp(@number)
    
  response = @random_mp.random_photo(3)["query"]
  if response
    @results_count = response["count"].to_i
  else
    @results_count = 0
  end
  
  if @results_count == 1
    @photos = [response["results"]["photo"]]
  elsif @results_count > 1
    @photos = response["results"]["photo"]
  end

  haml :index
end

get "/about" do
  haml :about
end

private
  def random_number(last_number)
    number = rand(MAX_NUMBER)+1
    while last_number == number
      number = rand(MAX_NUMBER)+1
    end
    number
  end
  
  def setup_mp(number)
    data_line = MPS_DATA[number]  
    mp_data = FasterCSV::parse_line(data_line)
    random_mp = MP.new(mp_data[1..2].join(" ").squeeze(" "), mp_data[3], mp_data[4], mp_data[5])
    random_mp
  end