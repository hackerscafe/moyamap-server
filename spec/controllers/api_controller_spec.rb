require 'spec_helper'

describe ApiController do

  describe "GET 'call_wiki'" do
    it "returns http success" do
      get 'call_wiki'
      response.should be_success
    end
  end

end
