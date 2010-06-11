require 'rubygems'
require 'json'
require 'yaml'
require 'oauth'

class MP
  attr_reader :name, :party, :constituency, :twfy_url, :number, :fymp_url
  
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
  
  TOKEN = get_yql_access_token()
  
  def self.get_mongo_connection
    if ENV['RACK_ENV'] && ENV['RACK_ENV'] == 'production'
      db_name = ENV['MONGO_DB']
      db_server = ENV['MONGO_SERVER']
      db_port = ENV['MONGO_PORT']
      db_user = ENV['MONGO_USER']
      db_pass = ENV['MONGO_PASS']
    else    
      mongo_conf = YAML.load(File.read('config/virtualserver/mongo.yml'))
      db_name = mongo_conf[:db]
      db_server = mongo_conf[:server]
      db_port = mongo_conf[:port]
      db_user = mongo_conf[:user]
      db_pass = mongo_conf[:pass]
    end

    db = Mongo::Connection.new(db_server, db_port).db(db_name)
    db.authenticate(db_user, db_pass)
    
    return db
  end
  
  MONGO_DB = get_mongo_connection()
  
  def twfy_photo
    query = "select * from html where url='#{self.twfy_url}' and xpath='//p[@class=\"person\"]/img'"
    result = TOKEN.request(:get, "/v1/yql?q=#{OAuth::Helper.escape(query)}&callback=&format=json")
    
    response = JSON.parse(result.body)
    
    if response.nil? or response.is_a?(String)
      return ""
    end
    
    unless response["query"]["results"]
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
    query = "select title, url from search.web where query='site:en.wikipedia.org #{self.name.gsub("'", "%27")} MP #{self.constituency}' limit 1"
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
    %Q|{"name":"#{name}","number":#{number},"party":"#{party}","constituency":"#{constituency}","twfy_url":"#{twfy_url}","twfy_photo":"#{twfy_photo}","wikipedia_url":"#{wikipedia_url}","wikipedia_photo":"#{wikipedia_photo}"}|
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
  
  def fymp_url
    constituency = self.constituency.downcase
    constituency.gsub!(" ","-")
    constituency.gsub!(",","")
    constituency.gsub!("(","")
    constituency.gsub!(")","")
    link = "http://findyourmp.parliament.uk/constituencies/#{constituency}"
  end
  
  private
    def do_search(search_term, qty)
      blocked_photos = get_blocked_photo_list(search_term)
      blocked_users = get_blocked_user_id_list()
      blocked_tags = get_blocked_tag_list()
      
      query = "select title,license,farm,id,secret,server,owner.username,owner.nsid, tags from flickr.photos.info where photo_id in (select id from flickr.photos.search(20) where tags\='#{search_term}' and id NOT MATCHES '#{blocked_photos}') and tags.tag.content NOT MATCHES '#{blocked_tags}' and owner.nsid NOT MATCHES '#{blocked_users}' limit #{qty}"
      
      result = TOKEN.request(:get, "/v1/yql?q=#{OAuth::Helper.escape(query)}&callback=&format=json")
      response = JSON.parse(result.body)
    end
    
    def get_blocked_tag_list
      coll = MONGO_DB.collection("blacklist")
      results = coll.find("tags" => /.*/)
      results.next_document["tags"].join("|")
    end
    
    def get_blocked_user_id_list
      coll = MONGO_DB.collection("blacklist")
      results = coll.find("users" => /.*/)
      results.next_document["users"].join("|")
    end
    
    def get_blocked_photo_list(mp_name)
      coll = MONGO_DB.collection("blacklist")
      blocked_outright = coll.find({"photo_id" => /.*/, "name" => nil}).collect { |x| x["photo_id"] }
      blocked_for_mp = coll.find({"photo_id" => /.*/, "name" => mp_name}).collect { |x| x["photo_id"] }
      
      (blocked_outright | blocked_for_mp).join("|")
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
