require 'rubygems'
require 'json'
require 'yaml'
require 'oauth'

class MP
  attr_reader :name, :party, :constituency, :twfy_url, :number
  
  def self.get_yql_access_token
    if ENV['RACK_ENV'] && ENV['RACK_ENV'] == 'production'
      key = ENV['YQL_KEY']
      secret = ENV['YQL_SECRET']
    else
      yql_conf = YAML.load(File.read('config/virtualserver/YQL.yml'))
      key = yql_conf[:YQL_KEY]
      secret = yql_conf[:YQL_SECRET]
    end
    
    consumer = OAuth::Consumer.new \
      key,
      secret,
      :site => "http://query.yahooapis.com"

    OAuth::AccessToken.new(consumer)
  end
  
  TOKEN = get_yql_access_token
  
  def twfy_photo
    query = "select * from html where url='#{self.twfy_url}' and xpath='//p[@class=\"person\"]/img'"
    result = TOKEN.request(:get, "/v1/yql?q=#{OAuth::Helper.escape(query)}&callback=&format=json")
    
    response = JSON.parse(result.body)
    
    if response.nil? or response.is_a?(String)
      return ""
    end
    
    src = response["query"]["results"]["img"]["src"]
    
    if src =~ /unknownperson/
      return ""
    else
      src = "http://www.theyworkforyou.com#{src}"
    end
    
    src
  end
  
  def wikipedia_url
    query = "select title, url from search.web where query='site:en.wikipedia.org #{self.name} MP #{self.constituency}' limit 1"
    result = TOKEN.request(:get, "/v1/yql?q=#{OAuth::Helper.escape(query)}&callback=&format=json")
    
    response = JSON.parse(result.body)

    if response.nil? or response.is_a?(String)
      return ""
    else
      return response["query"]["results"]["result"]["url"]
    end
  end
  
  def wikipedia_photo
    query = "select * from html where url='#{wikipedia_url}' and xpath='//table [@class=\"infobox vcard\"]/tr/td/a/img'"
    result = TOKEN.request(:get, "/v1/yql?q=#{OAuth::Helper.escape(query)}&callback=&format=json")
    
    response = JSON.parse(result.body)
    
    if !response["query"] || response["query"]["count"] == "0"
      return ""
    end
    
    if response["query"]["count"] == "1"
      src = response["query"]["results"]["img"]["src"]
    else 
      src = response["query"]["results"]["img"][0]["src"]
    end
    
    if src.downcase =~ /replace_this_image/
      src = ""
    end
    
    src    
  end
 
  def initialize(name, party, constituency, twfy_url, number)
    @name = remove_initials(name)
    @party = party
    @constituency = format_constituency_name(constituency)
    @twfy_url = twfy_url
    @number = number
  end

  def to_json
    %Q|{"name":"#{name}","party":"#{party}","constituency":"#{constituency}","twfy_url":"#{twfy_url}","twfy_photo":"#{twfy_photo}","wikipedia_url":"#{wikipedia_url}","wikipedia_photo":"#{wikipedia_photo}"}|
  end

  def lookup_flickr_photo_license
    { 0 => "&copy; All rights reserved", 1 => "<a href='http://creativecommons.org/licenses/by-nc-sa/2.0/'>Some rights reserved</a>", 2 => "<a href='http://creativecommons.org/licenses/by-nc/2.0/'>Some rights reserved</a>", 3 => "<a href='http://creativecommons.org/licenses/by-nc-nd/2.0/'>Some rights reserved</a>", 4 => "<a href='http://creativecommons.org/licenses/by/2.0/'>Some rights reserved</a>", 5 => "<a href='http://creativecommons.org/licenses/by-sa/2.0/'>Some rights reserved</a>", 6 => "<a href='http://creativecommons.org/licenses/by-nd/2.0/' title='Stuff about this licence'>Some rights reserved</a>", 7 => "<a href='http://flickr.com/commons/usage/'>No known copyright restrictions</a>" }
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
      query = "select title,license,farm,id,secret,server,owner.username,owner.nsid, tags from flickr.photos.info where photo_id in (select id from flickr.photos.search(20) where tags\='#{search_term}') and tags.tag.content NOT MATCHES '.*expenses.*|satire|flipping|thieves|thief|safeseat|headlines|longboards|gravytrain|fillthecabinet|publicart|sculpture|madness|motorsports|adolfhitler|robotdisaster|nazi|music|emohoc|churchmonuments|universalpictures|.*memorial|sacredstitchclothing|concertphotography|usa' and owner.username NOT MATCHES 'RinkRatz|brizzle born and bred|neate photos|.ju:femaiz|bench808|UCL Conservative Society|Ed\303\272|Hollandi985|MalibuImages|patbrowndocumentary|Neikirk Image|BBC Radio 5 live|http://www.WorcesterParkBlog.org.uk|Moff' limit #{qty}"
      
      result = TOKEN.request(:get, "/v1/yql?q=#{OAuth::Helper.escape(query)}&callback=&format=json")
      response = JSON.parse(result.body)
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
    
    def remove_initials name
      if name =~ /^[A-Z][a-z]*( [A-Z] )[A-Z][a-z]*$/
        name = name.gsub($1, " ")
      end
      name
    end
    
    def format_constituency_name name
      if name =~ /^([A-Za-z]*)\,\s*(City of|The)$/
        name = "#{$2.strip} #{$1.strip}"
      end
      name
    end
end
