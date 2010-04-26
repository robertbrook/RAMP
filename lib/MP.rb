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
  
  def random_photo
    self.class.get("/v1/public/yql/", :query => {
      :q => "select title,license,farm,id,secret,server,owner.username,owner.nsid from flickr.photos.info where photo_id in (select id from flickr.photos.search(1) where text='#{self.name.gsub(" ", "")}')",
      :format => 'json',
      :callback => ''
     })
  end
end