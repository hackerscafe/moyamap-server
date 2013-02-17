# -*- coding: utf-8 -*-
require 'localwiki_client'

class User < ActiveRecord::Base
  serialize :user_hash, Hash

  TAGS = ["ハッカソン", "カフェ", "残飯", "寿司", "すたみな太郎", "エロ", "かわいい店員", "廃人", "焼肉", "クソ", "破滅", "YAHOO", "Google", "GREE", "考えるのをやめろ", "レッドブル"]

  def crawl_checkins
    @graph = Koala::Facebook::API.new(self.fb_token)
    checkins = @graph.get_connections("me", "checkins")
    checkins.reverse!
    
    checkins.each do |checkin|
      place = checkin["place"]
      name = self.name + "/" + place["id"].to_s
      body = "<pre>" + {
          location_name: place["name"].to_s,
          message: checkin["message"].to_s,
          time: checkin["created_time"].to_s,
          user_name: self.user_hash["name"].to_s,
          user_id: self.user_hash["id"].to_s,
          picture_url: "https://graph.facebook.com/#{self.user_hash["id"]}/picture"
      }.to_yaml + "</pre>"

      location = place["location"]
      latitude = location["latitude"]
      longitude = location["longitude"]
      message = checkin["message"].to_s
      post_to_localwiki(name, body, latitude, longitude, message)
    end
    return true
  end


  private
  def post_to_localwiki(name, body, latitude, longitude, message) 
    args = {
      :base_url => Configurable[:local_wiki_server],
      :user_name => "apiuser",
      :api_key => Configurable[:local_wiki_api_key]
    }
    page = LocalWikiPage.new args
    page_hash = page.exist?(name)
    page_obj = {
      "content" => body,
      "name" => name
    }
    if page_hash.nil?
      unless page.create(page_obj)
        logger.debug("can't create page")
        return false
      end
      page_hash = page.exist?(name)
    else
      page_slug = page_hash["slug"]
      unless page.update(page_slug, page_obj)
        logger.debug("can't update page")
        return false
      end
    end
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
    if map.exist?(name)
      map.delete(name)
    end
    unless map.create(map_obj)
      logger.debug("can't create map")
    end
    page_slug = page_hash["slug"]
    search_and_add_tag(args, page_slug, body, page_api_location, message)
    return true
  end

  def search_and_add_tag(args, page_slug, body, page_api_location, message)
    tag_names = get_match_tags(message)
    unless tag_names.blank?
      tag_names.each do |tag_name|
        #tag_resource_uri = fetch_or_create_tag(args, tag_name)
        tag_hash = LocalWikiUtil.fetch_or_create_tag(args, tag_name)
        #if tag_resource_uri
        if tag_hash
          tag_resource_uri = tag_hash["resource_uri"]
          tag_slug = tag_hash["slug"]
          LocalWikiUtil.add_or_new_tag(args, page_slug, page_api_location, tag_resource_uri, tag_slug)
        end
      end
    end
  end

  def get_match_tags(message)
    TAGS.select do |tag|
      Regexp.new(tag) =~ message
    end
  end
end
