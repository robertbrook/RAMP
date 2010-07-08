require File.dirname(__FILE__) + '/spec_helper'

describe "MP" do
  include Rack::Test::Methods

  def app
    @app ||= Sinatra::Application
  end

  describe "when formatting a name for use in a URL" do
    it "should return 'dave-smith' when passed 'Dave Smith'" do
      MP.format_name_for_url("Dave Smith").should == "dave-smith"
    end
    
    it "should return 'david-smith--jones' when passed 'David Smith-Jones'" do
      MP.format_name_for_url("David Smith-Jones").should == "david-smith--jones"
    end
  end
end