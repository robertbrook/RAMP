require 'rubygems'
require 'fastercsv'

class Party
  
  MPS_DATA = File.new("./public/mps.csv").readlines
  
  def self.party_list
    row_count = 0
    party = ""
    list = []
    MPS_DATA.each do |line|
      if row_count > 0
        mp_data = FasterCSV::parse_line(line)
        party = mp_data[3]
        unless list.include?(party)
          if party != "-"
            list << party
          end
        end
      end
      row_count += 1
    end
    list
  end
  
end