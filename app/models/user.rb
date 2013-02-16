# -*- coding: utf-8 -*-
require 'localwiki_client'

class User < ActiveRecord::Base
  serialize :user_hash, Hash

  def crawl_checkins
    @graph = Koala::Facebook::API.new(self.fb_token)
    checkins = @graph.get_connections("me", "checkins")
    
    checkins.each do |checkin|
      place = checkin["place"]
      name = self.name + "/" + place["id"]
      body = place["name"]
      location = place["location"]
      latitude = location["latitude"]
      longitude = location["longitude"]
      post_to_localwiki(name, body, latitude, longitude)
    end
    
  end


  private
  def post_to_localwiki(name, body, latitude, longitude) 
    args = {
      :base_url => "http://moya-map.trick-with.net/",
      :user_name => "apiuser",
      :api_key => Configurable[:local_wiki_api_key]
    }
    page = LocalWikiPage.new args
    page_obj = {
      "content" => body,
      "name" => name
    }
    unless page.create(page_obj)
      logger.debug("can't create page")
      return false
    end
    page_hash = page.exist?(name)
    page_api_location = page_hash["resource_uri"]
    map_obj = {
      "geom" => {
        "geometries" => [
                         {
                           "coordinates" => [ longitude, latitude ],
                           "type" => "Point"
                         }
                        ],
        "type" => "GeometryCollection"
      },
      "page" => page_api_location
    }
    map = LocalWikiMap.new args
    unless map.create(map_obj)
      logger.debug("can't create map")
      return false
    end
    return true
  end

end
