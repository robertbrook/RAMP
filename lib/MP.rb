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
    
    images = do_search(search_term, qty)
     
    if !images["query"] || images["query"]["count"] == "0"
      search_term = alternate_name + " MP"  
      images = do_search(search_term, qty)
    end
    
    images
  end
  
  private
    def do_search(search_term, qty)
      self.class.get("/v1/public/yql/", :query => {
         :q => "select title,license,farm,id,secret,server,owner.username,owner.nsid, tags from flickr.photos.info where photo_id in (select id from flickr.photos.search(20) where text='#{search_term}') and tags.tag.content NOT MATCHES 'expenses|satire|flipping|thieves|thieft|safeseat|madness|robotdisaster|nazi' and owner.username != 'RinkRatz' and owner.username != 'brizzle born and bred' limit #{qty}",
         :format => 'json',
         :callback => ''
      })
    end
  
    def alternate_name
      name = self.name
      name = name.gsub("Christopher", "Chris")
      name = name.gsub("Nicholas", "Nick")
      name = name.gsub("Kenneth", "Ken")
      name = name.gsub("Thomas", "Tom")
      name
    end
  
end