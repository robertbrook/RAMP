require 'rubygems'
require 'sinatra'
require 'open-uri'
require 'json'
require 'haml'

module Feed
   class << self
    def base
      "http://query.yahooapis.com/v1/public/yql?q=select%20title%2Clicense%2Cfarm%2Cid%2Csecret%2Cserver%2Cowner.username%2Cowner.nsid%20from%20flickr.photos.info%20where%20photo_id%20in%20(select%20id%20from%20flickr.photos.search(10)%20where%20text%3D"
    end
        
    def get(mp = '')
      uri = "#{base}" 
      uri << "'#{ URI.escape(mp)}'" unless mp.empty?
      uri << ")&format=json&callback="
      JSON.parse(open(uri).read)["query"]["results"]["photo"]
    end    
  end
end

get '/' do
  @mp = "vincecable"
  @photos = Feed.get @mp
  haml :index
end



