require File.dirname(__FILE__) + '/spec_helper'
#require 'json'

describe "RAMP" do
  include Rack::Test::Methods

  def app
    @app ||= Sinatra::Application
  end

  it "should respond to /" do
    mock_mp = mock(MP)
    mock_mp.stub!(:json).and_return('{"name":"Dave Smith"}')
    mock_mp.stub!(:random_photo).and_return('{"query":{"count":"0"}}')
    MP.should_receive(:new).and_return(mock_mp)
    
    get '/'
    last_response.should be_ok
  end
end