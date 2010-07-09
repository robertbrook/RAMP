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
      image_found_response = '{"query":{"count":"1","results":{"img":{"src":"/images/mps/11148.jpg"}}}}'
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
  
  describe "when asked for wikipedia_url" do
    before do
      @mp = MP.new("Dave Smith", "Test Party", "Croydon West", "http://example.com", 42)
      @token = mock(OAuth::AccessToken)
      @response = mock(Net::HTTPOK)
    end
    
    it 'should return an wikipedia url when a wikipedia entry is found' do
      found_response = '{"query": {"count": "1","results": {"result": {"url": "http://en.wikipedia.org/wiki/Dave_Smith"}}}}'
      @response.stub!(:body).and_return(found_response)
      @token.stub!(:request).and_return(@response)
      @mp.should_receive(:yql_token).and_return(@token)
      
      @mp.wikipedia_url.should == "http://en.wikipedia.org/wiki/Dave_Smith"
    end
    
    it 'should return a blank string when no wikipedia entry is found' do
      image_not_found_response = "{\"query\":{\"count\":\"0\"}}"
      @response.stub!(:body).and_return(image_not_found_response)
      @token.stub!(:request).and_return(@response)   
      @mp.should_receive(:yql_token).and_return(@token)
      
      @mp.wikipedia_url.should == ""
    end
  end
  
  describe "when asked for wikipedia_photo" do
    before do
      @mp = MP.new("Dave Smith", "Test Party", "Croydon West", "http://example.com", 42)
      @mp.stub!(:wikipedia_url).and_return("http://en.wikipedia.org/wiki/Dave_Smith")
      @token = mock(OAuth::AccessToken)
      @response = mock(Net::HTTPOK)
    end
    
    it 'should return an wikipedia photo url when a wikipedia photo is found' do      
      found_response = '{"query": {"count": "1","results": {"img": {"src": "http://upload.wikimedia.org/wikipedia/commons/fake_image.jpg"}}}}'
      @response.stub!(:body).and_return(found_response)
      @token.stub!(:request).and_return(@response)
      @mp.should_receive(:yql_token).and_return(@token)
      
      @mp.wikipedia_photo.should == "http://upload.wikimedia.org/wikipedia/commons/fake_image.jpg"
    end
    
    it 'should return a blank string when no wikipedia entry is found' do
      image_not_found_response = "{\"query\":{\"count\":\"0\"}}"
      @response.stub!(:body).and_return(image_not_found_response)
      @token.stub!(:request).and_return(@response)   
      @mp.should_receive(:yql_token).and_return(@token)
      
      @mp.wikipedia_photo.should == ""
    end
  end

  describe "when asked for fymp_url" do
    it 'should return a url ending gloucester' do
      mp = MP.new("Dave Smith", "Test Party", "Gloucester", "http://example.com", 42)
      mp.fymp_url.should == "http://findyourmp.parliament.uk/constituencies/gloucester"
    end
    
    it 'should handle spaces correctly' do
      mp = MP.new("Dave Smith", "Test Party", "Croydon South", "http://example.com", 42)
      mp.fymp_url.should == "http://findyourmp.parliament.uk/constituencies/croydon-south"
    end
    
    it 'should handle Ynys Môn correctly' do
      mp = MP.new("Dave Smith", "Test Party", "Ynys Môn", "http://example.com", 42)
      mp.fymp_url.should == "http://findyourmp.parliament.uk/constituencies/ynys-mon"
    end
    
    it 'should handle commas correctly' do
      mp = MP.new("Dave Smith", "Test Party", "Inverness, Nairn, Badenoch and Strathspey", "http://example.com", 42)
      mp.fymp_url.should == "http://findyourmp.parliament.uk/constituencies/inverness-nairn-badenoch-and-strathspey"
    end
    
    it 'should handle brackets correctly' do
      mp = MP.new("Dave Smith", "Test Party", "Richmond (Yorks)", "http://example.com", 42)
      mp.fymp_url.should == "http://findyourmp.parliament.uk/constituencies/richmond-yorks"
    end
  end
end