require 'spec/rake/spectask'
require 'rubygems'
require 'fastercsv'
require 'memcached'
require 'lib/MP'

Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ['--colour', '--format=specdoc']
end

desc "Flushes the memcached data"
task :clear_memcache do
  cache = Memcached.new()
  cache.flush()
end

desc "Cron job to populate memcached"
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
      
      #try to find the data before adding
      begin
        cached_mp = cache.get("mp_#{row_count}")
        unless cached_mp == json
          cache.replace("mp_#{row_count}", json)
        end
      rescue Memcached::NotFound
        cache.add("mp_#{row_count}", json)
      end
    end
    row_count += 1
  end
end