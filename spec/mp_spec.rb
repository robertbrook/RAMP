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
  
  describe "when asked for twfy_photo" do
    before do
      @mp = MP.new("Dave Smith", "Test Party", "Croydon West", "http://example.com", 42)
      @token = mock(OAuth::AccessToken)
      @response = mock(Net::HTTPOK)
    end
    
    it 'should return an image url where an image is found' do      
      image_found_response = "{\"query\":{\"count\":\"1\",\"results\":{\"img\":{\"src\":\"/images/mps/11148.jpg\"}}}}"
      @response.stub!(:body).and_return(image_found_response)
      @token.stub!(:request).and_return(@response)
      @mp.should_receive(:yql_token).and_return(@token)
      
      @mp.twfy_photo.should == "http://www.theyworkforyou.com/images/mps/11148.jpg"
    end
    
    it 'should return a blank string where an image is not found' do
      image_not_found_response = "{\"query\":{\"count\":\"0\"}}"
      @response.stub!(:body).and_return(image_not_found_response)
      @token.stub!(:request).and_return(@response)   
      @mp.should_receive(:yql_token).and_return(@token)
      
      @mp.twfy_photo.should == ""
    end
  end
end