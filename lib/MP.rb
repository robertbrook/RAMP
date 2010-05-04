require 'rubygems'
require 'httparty'

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
  
  def twfy_photo    
    response = self.class.get("/v1/public/yql/", :query => {
      :q => "select * from html where url='#{self.twfy_url}' and xpath='//p[@class=\"person\"]/img'",
      :format => 'json',
      :callback => ''
    })
    
    src = response["query"]["results"]["img"]["src"]
    "http://www.theyworkforyou.com#{src}"
  end
  
  def wikipedia_url
    response = self.class.get("/v1/public/yql/", :query => {
      :q => "select title, url from search.web where query='site:en.wikipedia.org #{self.name} MP #{self.constituency}' limit 1",
      :format => 'json',
      :callback => ''
    })
    
    response["query"]["results"]["result"]["url"]
  end
 
  def initialize(name, party, constituency, twfy_url)
    @@name = name
    @@party = party
    @@constituency = constituency
    @@twfy_url = twfy_url
  end
  
  def random_photo(qty=1)
    search_name = self.name.gsub("Nicholas Clegg", "Nick Clegg")
    search_name = search_name.gsub("Vincent Cable", "Vince Cable")
    search_term = search_name.gsub(" ", "")
    
    images = do_search(search_term, qty)
     
    if !images["query"] || images["query"]["count"] == "0"
      search_term = alternate_name.gsub(" ", "")
      images = do_search(search_term, qty)
    end
    
    images
  end
  
  private
    def do_search(search_term, qty)
      self.class.get("/v1/public/yql/", :query => {
         :q => "select title,license,farm,id,secret,server,owner.username,owner.nsid, tags from flickr.photos.info where photo_id in (select id from flickr.photos.search(20) where tags\='#{search_term}') and tags.tag.content NOT MATCHES '.*expenses.*|satire|flipping|thieves|thief|safeseat|headlines|longboards|gravytrain|fillthecabinet|publicart|sculpture|madness|motorsports|adolfhitler|robotdisaster|nazi|music|emohoc|churchmonuments|universalpictures|.*memorial|sacredstitchclothing|concertphotography|usa' and owner.username NOT MATCHES 'RinkRatz|brizzle born and bred|neate photos|.ju:femaiz|bench808|UCL Conservative Society|Ed\303\272|Hollandi985|MalibuImages|patbrowndocumentary|Neikirk Image|BBC Radio 5 live|http://www.WorcesterParkBlog.org.uk|Moff' limit #{qty}",
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
      name = name.gsub("Vincent", "Vince")
      name = name.gsub("Edward", "Ed")
      name = name.gsub("Gregory", "Greg")
      
      name
    end
  
end