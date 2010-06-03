require 'rubygems'
require 'sinatra'
require 'json'
require 'haml'
require 'fastercsv'
require 'memcached'
require 'lib/MP'

enable :sessions

MPS_DATA = File.new("./public/mps.csv").readlines
MAX_NUMBER = MPS_DATA.length - 1
CACHE = Memcached.new()

get '/env' do
  "<code>" + ENV.inspect + "</code>"
end

get '/favicon.ico' do
  ""
end

get '/stylesheets/styles.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :styles
end

get '/' do
  session[:page_nums] = session[:mp_nums]
  
  @number = params[:num]
  if @number
    @number = @number.to_i
  else
    @number = random_mp_num(true)
  end
  
  unless session[:attempts]
    session[:attempts] = 1
  else
    session[:attempts] += 1
  end
  
  session[:last] = "" unless session[:last]
  session[:correct] = 0 unless session[:correct]
  session[:wrong] = 0 unless session[:wrong]
  session[:passes] = session[:attempts] - (session[:correct] + session[:wrong] + 1)
  
  @random_mp = setup_mp(@number)
  @photos = get_photos(@random_mp)

  begin
    mp_cache = CACHE.get("mp_#{@number}")
    @random_mp_json = JSON.parse(mp_cache)
  rescue Memcached::NotFound
    @random_mp_json = JSON.parse(@random_mp.to_json)
    CACHE.add("mp_#{@number}", JSON.generate(@random_mp_json))
  end

  status = []

  if @photos.size > 0
    mp1_number = random_mp_num(false)
    alt_mp1 = setup_mp(mp1_number)
    alt_mp1_json = ""
    begin
      mp_cache = CACHE.get("mp_#{mp1_number}")
      alt_mp1_json = JSON.parse(mp_cache)
    rescue Memcached::NotFound
      alt_mp1_json = JSON.parse(alt_mp1.to_json)
      CACHE.add("mp_#{mp1_number}", JSON.generate(alt_mp1_json))
    end
    
    mp2_number = random_mp_num(false)
    alt_mp2 = setup_mp(mp2_number)
    alt_mp2_json = ""
    begin
      mp_cache = CACHE.get("mp_#{mp2_number}")
      alt_mp2_json = JSON.parse(mp_cache)
    rescue Memcached::NotFound
      alt_mp2_json = JSON.parse(alt_mp2.to_json)
      CACHE.add("mp_#{mp2_number}", JSON.generate(alt_mp2_json))
    end
  
    pos = rand(3)
  
    @mps = []
    0.upto(2) do |i|
      if i == pos
        @mps << @random_mp_json
        status << @number
      elsif @mps.include?(alt_mp1_json)
        @mps << alt_mp2_json
        status << mp2_number
      else
        @mps << alt_mp1_json
        status << mp1_number
      end
    end
  
    status.delete(@number)
    status.reverse!
    status << @number
    @status = status.join("-")
  
    session[:page_nums] = session[:mp_nums]
  end
  
  haml :index
end

post "/answer" do
  @status = params[:status].split("-")
  @answer = @status.last
  @guess = params[:guess]
  
  @mp = setup_mp(@answer.to_i)
  @chosen = setup_mp(@guess.to_i)
  
  begin
    mp_cache = CACHE.get("mp_#{@answer}")
    @mp_json = JSON.parse(mp_cache)
  rescue Memcached::NotFound
    @mp_json = JSON.parse(@mp.to_json)
    CACHE.add("mp_#{@answer}", JSON.generate(@mp_json))
  end
  
  
  unless session[:last] == @status
    if @guess == @answer
      session[:correct] +=1
    else
      session[:wrong] +=1
    end
    session[:passes] = session[:attempts] - (session[:correct] + session[:wrong])
  end
  
  session[:last] = @status
  
  haml :answer
end

get "/about" do
  haml :about
end

private
  def random_mp_num write_back
    unless session[:mp_nums]
      session[:mp_nums] = (1..MAX_NUMBER).to_a
    end
    unless session[:page_nums]
      session[:page_nums] = (1..MAX_NUMBER).to_a
    end
    numbers = session[:page_nums]
    numbers = numbers.sort_by{rand}
    random = numbers.pop
    if write_back
      session[:mp_nums] = numbers
    end
    session[:page_nums] = numbers
    return random
  end
  
  def setup_mp(number)
    data_line = MPS_DATA[number]
    mp_data = FasterCSV::parse_line(data_line)
    MP.new(mp_data[1..2].join(" ").squeeze(" "), mp_data[3], mp_data[4], mp_data[5], number)
  end
  
  def get_photos(random_mp)
    photos = []
    response = random_mp.random_photo(3)["query"]
    if response
      results_count = response["count"].to_i
    else
      results_count = 0
    end

    if results_count == 1
      photos = [response["results"]["photo"]]
    elsif results_count > 1
      photos = response["results"]["photo"]
    end
    photos
  end
