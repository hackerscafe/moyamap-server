require 'spec_helper'

describe "Api" do
  describe "GET /api/page/" do
    it "gets page" do
      get "api/page.json", {name: "test5"}.to_json
      response.status.should eq 200
    end
  end
  describe "POST /api/page/" do
    it "creates page" do
      post "api/page.json", {name: "test5", content: "This is test page."}.to_json
      response.status.should eq 201
    end
  end
end
