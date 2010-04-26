require 'rubygems'
require 'sinatra'
require 'open-uri'
require 'json'
require 'haml'
require 'HTTParty'

MP_FILE = File.new("./public/mps.csv")

module MP
  include HTTParty
  base_uri 'http://query.yahooapis.com'

  def self.random_photo(mp_name = '')
      get("/v1/public/yql/", :query => {
        :q => "select title,license,farm,id,secret,server,owner.username,owner.nsid from flickr.photos.info where photo_id in (select id from flickr.photos.search(1) where text='#{mp_name}')",
        :format => 'json',
        :callback => ''
       })
    end
 
end

get '/' do
  @random_mp = MP_FILE.readlines[rand(644)].split(',')
  @mp_name = @random_mp[1..2].join()
  @mp_party = @random_mp[3]
  @mp_constituency = @random_mp[4]
  @mp_twfy_url = @random_mp[5]
  @results = MP.random_photo(@mp_name)["query"]["results"]
  
  if @results
    @photos = @results
  else
    @photos = ["Sorry: we couldn't find a photo of #{@mp_name}"]
  end

  haml :index
end



