require 'rubygems'
require 'sinatra'
require 'json'
require 'haml'
require 'sass'
require 'fastercsv'
require 'iconv'
require 'memcached'
require 'mongo'
require 'htmlentities'
require 'lib/MP'
require 'helpers/partials'
require 'helpers/auth'

enable :sessions

MPS_DATA = File.new("./public/mps.csv").readlines
MAX_NUMBER = MPS_DATA.length - 1
CACHE = Memcached.new()

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

get '/stylesheets/styles.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :styles
end

get '/' do
  session[:page_nums] = session[:mp_nums]
  session[:flagged] = ""
  
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

  @random_mp_json = get_mp_json(@number, @random_mp)

  status = []

  if @photos.size > 0
    mp1_number = random_mp_num(false)
    alt_mp1 = setup_mp(mp1_number)
    alt_mp1_json = ""
    alt_mp1_json = get_mp_json(mp1_number, alt_mp1)
    
    mp2_number = random_mp_num(false)
    alt_mp2 = setup_mp(mp2_number)
    alt_mp2_json = ""
    alt_mp2_json = get_mp_json(mp2_number, alt_mp2)
  
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

#flagging a photo
post "/" do
  session[:page_nums] = session[:mp_nums]
  @flagged = session[:flagged]
  
  if @flagged
    @flagged = @flagged.split("-")
  else
    @flagged = []
  end
  
  status = params[:status].split("-")
  @number = status.last.to_i
  
  @random_mp = setup_mp(@number)
  @photos = get_photos(@random_mp)
  
  photo_id = params[:photo_id]
  
  user_id = params[:user_id]
  user_name = params[:user_name]
  mp_name = @random_mp.name
  
  @flagged << photo_id
  
  farm = ""
  server = ""
  secret = ""
  
  @photos.each do |photo|
    if photo["id"] == photo_id
      farm = photo["farm"]
      server = photo["server"]
      secret = photo["secret"]
      break
    end
  end
  
  flag_photo(photo_id, user_id, user_name, mp_name, farm, server, secret)
  
  @random_mp_json = get_mp_json(@number, @random_mp)

  if @photos.size > 0
    mp1_number = status[0].to_i
    alt_mp1 = setup_mp(mp1_number)
    alt_mp1_json = ""
    alt_mp1_json = get_mp_json(mp1_number, alt_mp1)
    
    mp2_number = status[1].to_i
    alt_mp2 = setup_mp(mp2_number)
    alt_mp2_json = ""
    alt_mp2_json = get_mp_json(mp2_number, alt_mp2)

    pos = rand(3)
  
    @mps = []
    0.upto(2) do |i|
      if i == pos
        @mps << @random_mp_json
      elsif @mps.include?(alt_mp1_json)
        @mps << alt_mp2_json
      else
        @mps << alt_mp1_json
      end
    end
  
    @status = status.join("-")
  end
  
  session[:flagged] = @flagged.join("-")
  
  haml :index
end

post "/answer" do
  @status = params[:status].split("-")
  @answer = @status.last
  @guess = params[:guess]
  
  @mp = setup_mp(@answer.to_i)
  @chosen = setup_mp(@guess.to_i)
  
  @mp_json = get_mp_json(@answer, @mp)
  
  unless session[:last] == @status
    if @guess == @answer
      session[:correct] = 0 unless session[:correct]
      session[:correct] +=1
    else
      session[:wrong] = 0 unless session[:wrong]
      session[:wrong] +=1
    end
    session[:attempts] = 1 unless session[:attempts]
    session[:passes] = session[:attempts] - (session[:correct] + session[:wrong])
  end
  
  session[:last] = @status
  
  haml :answer
end

get "/about" do
  haml :about
end

get "/admin/stoplist" do
  do_auth()
  
  collection = MONGO_DB.collection("stoplist")
    
  #hashes
  @stoplist_photos = collection.find({"photo_id" =>  /.+/, "name" => nil})
  @stoplist_mp_photos = collection.find({"photo_id" =>  /.+/, "name" => /.+/})

  #arrays
  @stoplist_users = collection.find({"users" =>  /.+/}).next_document()["users"]
  @stoplist_tags = collection.find({"tags" =>  /.+/}).next_document()["tags"]
  
  haml :stoplist
end

get "/admin" do
  do_auth()

  coll = MONGO_DB.collection("flags")
  
  flags_by_mp = coll.group(["name"], {"name" => /.+/}, { "flags" => 0 }, "function(doc,rtn) { rtn.flags += 1; }")
  @flags_by_mp = flags_by_mp.sort_by { |x| -x["flags"] }
  
  flags_by_flickr_account = coll.group(["author_id", "author_name"], {"author_id" => /.+/}, { "flags" => 0 }, "function(doc,rtn) { rtn.flags += 1; }")
  @flags_by_flickr_account = flags_by_flickr_account.sort_by { |x| -x["flags"] }
  
  flags_by_photos = coll.group(["photo_id", "author_id", "flickr_secret", "flickr_farm", "flickr_server"], {"photo_id" => /.+/}, { "flags" => 0 }, "function(doc,rtn) { rtn.flags += 1; }")
  @flags_by_photos = flags_by_photos.sort_by { |x| -x["flags"] }
  
  haml :admin
end

get "/admin/account/:account_id" do
  @account_id = params[:account_id]
  
  coll = MONGO_DB.collection("flags")
  results = coll.find({"author_id" => "#{@account_id}"})
  first = results.next_document()
  
  unless first
    redirect "/admin"
  else
    @account_name = first["author_name"]
  end
  
  flagged = coll.group(["name", "photo_id", "author_id", "flickr_secret", "flickr_farm", "flickr_server"], {"author_id" => "#{@account_id}"}, { "flags" => 0 }, "function(doc,rtn) { rtn.flags += 1; }")
  @flagged = flagged.sort_by { |x| -x["flags"] }
  
  haml :account_flags
end

get "/admin/mp/:mp_name" do
  mp_name = params[:mp_name]
  display_name = mp_name.gsub("-", " ")
  display_name.gsub!("  ", "-")
  
  a2 = []
  a1 = display_name.split(" ")
  a1.each do |name|
    a2 << name.capitalize
  end
  
  @mp_name = a2.join(" ")
  
  coll = MONGO_DB.collection("flags")
  flagged = coll.group(["name", "photo_id", "author_id", "flickr_secret", "flickr_farm", "flickr_server"], {"name" => "#{@mp_name}"}, { "flags" => 0 }, "function(doc,rtn) { rtn.flags += 1; }")
  @flagged = flagged.sort_by { |x| -x["flags"] }
  
  haml :mp_flags
end

get "/admin/unflag/photo/:photo_id" do
  do_auth()
  
  coll = MONGO_DB.collection("flags")
  
  coll.remove("photo_id" => "#{params[:photo_id]}")
  
  if params[:return]
    redirect "#{params[:return]}"
  else
    redirect "/admin"
  end
end

get "/admin/unflag/user/:user_id" do
  do_auth()
  
  coll = MONGO_DB.collection("flags")
  
  coll.remove("author_id" => "#{params[:user_id]}")
  
  if params[:return]
    redirect "#{params[:return]}"
  else
    redirect "/admin"
  end
end

get "/admin/add_to_stoplist/photo/:photo_id" do
  do_auth()
  
  photo_id =  params[:photo_id]
  
  #get the flag values to move across
  coll = MONGO_DB.collection("flags")
  photo = coll.find("photo_id" => "#{photo_id}").next_document()
  
  if photo
  #add a new document to the stoplist
    coll = MONGO_DB.collection("stoplist")
    new_photo_doc = {"photo_id" => "#{photo_id}", "flickr_secret" => "#{photo["flickr_secret"]}", "flickr_farm" => "#{photo["flickr_farm"]}", "flickr_server" => "#{photo["flickr_server"]}", "author_id" => "#{photo["author_id"]}"}
    coll.insert(new_photo_doc)
  end
  
  #remove the "old" document from the flags collection
  coll = MONGO_DB.collection("flags")
  coll.remove("photo_id" => "#{photo_id}")
  
  if params[:return]
    redirect "#{params[:return]}"
  else
    redirect "/admin"
  end
end

get "/admin/add_to_stoplist/mp_photo/:mp_name/:photo_id" do
  do_auth()
  
  coll = MONGO_DB.collection("stoplist")
  
  mp_name = params[:mp_name]
  mp_name.gsub!("-", " ")
  mp_name.gsub!("  ", "-")
  
  photo_id =  params[:photo_id]
  
  #get the flag values to move across
  coll = MONGO_DB.collection("flags")
  photo = coll.find("photo_id" => "#{photo_id}", "name" => "#{mp_name}").next_document()
  
  #add a new document to the stoplist
  coll = MONGO_DB.collection("stoplist")
  new_photo_doc = {"photo_id" => "#{photo_id}", "name" => "#{mp_name}", "flickr_secret" => "#{photo["flickr_secret"]}", "flickr_farm" => "#{photo["flickr_farm"]}", "flickr_server" => "#{photo["flickr_server"]}", "author_id" => "#{photo["author_id"]}"}
  coll.insert(new_photo_doc)
  
  #remove the "old" document from the flags collection
  coll = MONGO_DB.collection("flags")
  coll.remove("photo_id" => "#{photo_id}", "name" => "#{mp_name}")
  
  if params[:return]
    redirect "/#{params[:return]}"
  else
    redirect "/admin"
  end
end

get "/admin/add_to_stoplist/user/:user_id" do
  do_auth()
  
  coll = MONGO_DB.collection("stoplist")
  
  user_doc = coll.find("users" => /.+/)
  
  first = user_doc.next_document()
  
  unless first
    redirect "/admin"
  else
    users = first["users"]
  end

  unless users.include?([params[:user_id]])
    users << params[:user_id]
  
    new_user_doc = {"users" => users}
    coll.update({ "users" => /.+/}, new_user_doc)
  end
  
  coll = MONGO_DB.collection("flags")
  coll.remove("author_id" => "#{params[:user_id]}")
  
  if params[:return]
    redirect "#{params[:return]}"
  else
    redirect "/admin"
  end
end

get '/login' do
  haml :admin_login
end

post '/login' do
  if ENV['RACK_ENV'] && ENV['RACK_ENV'] == 'production'
    user = ENV['ADMIN_USER']
    pass = ENV['ADMIN_PASS']
  else
    admin_conf = YAML.load(File.read('config/virtualserver/admin.yml'))
    user = admin_conf[:user]
    pass = admin_conf[:pass]
  end

  if params[:user] == user && params[:pass] == pass
    session[:authorized] = true
    redirect '/admin'
  else
    session[:authorized] = false
    redirect '/login'
  end
end

private
  def do_auth
    ip = @env["REMOTE_HOST"]
    ip = @env["REMOTE_ADDR"] unless ip
    ip = @env["HTTP_X_REAL_IP"] unless ip
    authorize!(ip)
  end
  
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
    
    valid_string = Iconv.iconv('utf-8', 'latin1', mp_data[1..2].join(" ").squeeze(" "))
    mp_name = HTMLEntities.new.encode(valid_string, :named)
    
    valid_string = Iconv.iconv('utf-8', 'latin1', mp_data[4])
    constituency = HTMLEntities.new.encode(valid_string, :named)
    
    MP.new(mp_name, mp_data[3], constituency, mp_data[5], number)
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
  
  def get_mp_json(number, mp)
    begin
      mp_cache = CACHE.get("mp_#{number}")
      result = JSON.parse(mp_cache)
    rescue Memcached::NotFound
      result = JSON.parse(mp.to_json)
      CACHE.add("mp_#{number}", JSON.generate(result))
    end
    result
  end

  def flag_photo(photo_id, user_id, user_name, mp_name, farm, server, secret)
    coll = MONGO_DB.collection("flags")
    
    flag = {"name" => "#{mp_name}", "photo_id" => "#{photo_id}", "author_id" => "#{user_id}", "author_name" => "#{user_name}", "flickr_farm" => "#{farm}", "flickr_server" => "#{server}", "flickr_secret" => "#{secret}"}
    coll.insert(flag)
  end
