require 'rubygems'
require 'HTTParty'

class MP
  @@name = ""
  @@party = ""
  @@constituency = ""
  @@twfy_url = ""
  
  include HTTParty
  base_uri 'http://query.yahooapis.com'
 
  def name
    @@name
  end
 
  def party
    @@party
  end
  
  def constituency
    @@constituency
  end
  
  def twfy_url
    @@twfy_url
  end
 
  def initialize(name, party, constituency, twfy_url)
    @@name = name
    @@party = party
    @@constituency = constituency
    @@twfy_url = twfy_url
  end
  
  def random_photo(qty=1)
    search_term = self.name + " MP"
    
    self.class.get("/v1/public/yql/", :query => {
      :q => "select title,license,farm,id,secret,server,owner.username,owner.nsid from flickr.photos.info where photo_id in (select id from flickr.photos.search(#{qty}) where text='#{search_term}')",
      :format => 'json',
      :callback => ''
     })
  end
end