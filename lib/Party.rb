require 'rubygems'
require 'fastercsv'

class Party
  attr_reader :name
  
  MPS_DATA = File.new("./public/mps.csv").readlines
  
  def initialize name
    @name = name
  end
  
  def self.party_list
    row_count = 0
    party = ""
    list = []
    MPS_DATA.each do |line|
      if row_count > 0
        mp_data = FasterCSV::parse_line(line)
        party = mp_data[3]
        unless list.include?(party)
          party = "Speaker" if party == "-"
          list << party
        end
      end
      row_count += 1
    end
    list
  end

  def mp_list
    row_count = 0
    mps = []
    MPS_DATA.each do |line|
      if row_count > 0
        mp_data = FasterCSV::parse_line(line)
        party = mp_data[3]
        if party == self.name
          mp = PartyMember.new("#{mp_data[1]} #{mp_data[2]}", row_count)
          mps << mp
        end
      end
      row_count += 1
    end
    mps
  end
  
end

class PartyMember
  attr_reader :name, :csv_line
  
  def initialize name, csv_line
    @name = name
    @csv_line = csv_line
  end
end