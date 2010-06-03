require 'spec/rake/spectask'
require 'rubygems'
require 'fastercsv'
require 'memcached'
require 'lib/MP'

Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ['--colour', '--format=specdoc']
end

task :cron do
  cache = Memcached.new()
    
  mp_data = File.new("public/mps.csv").readlines
  row_count = 0
  
  mp_data.each do |line|
    if row_count > 0
      mp_data = FasterCSV::parse_line(line)
      
      party = mp_data[3]
      party = "Speaker" if party == "-"
      
      mp = MP.new(mp_data[1..2].join(" ").squeeze(" "), party, mp_data[4], mp_data[5], row_count)
      
      json = mp.to_json
      
      #try to find the data
      cached_mp = nil
      begin
        cached_mp = cache.get("mp_#{row_count}")
      rescue Memcached::NotFound
        cache.add("mp_#{row_count}", json)
      end
    end
    row_count += 1
  end
end