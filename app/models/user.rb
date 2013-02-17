# -*- coding: utf-8 -*-
require 'localwiki_client'

class User < ActiveRecord::Base
  serialize :user_hash, Hash

  TAGS = ["ハッカソン", "カフェ", "残飯", "寿司", "すたみな太郎", "エロ", "かわいい店員", "廃人", "焼肉", "クソ", "破滅", "YAHOO", "Google", "GREE", "考えるのをやめろ"]

  def crawl_checkins
    @graph = Koala::Facebook::API.new(self.fb_token)
    checkins = @graph.get_connections("me", "checkins")
    
    checkins.each do |checkin|
      place = checkin["place"].to_s
      name = self.name + "/" + place["id"].to_s
      #body = place["name"]
#location_name=六本木 (Roppongi)
#message=破滅なう
#time=2013-02-16 20:00
#user_name=btm.smellman
#user_id=1173133984
#pic_url=https://graph.facebook.com/1173133984/picture
      body = ["location_name=" + place["name"].to_s, 
              "message=" + checkin["message"].to_s,
              "time=" + checkin["created_time"].to_s,
              "user_name=" + self.user_hash["name"].to_s,
              "user_id=" + self.user_hash["id"].to_s,
              "picture_url=" + "https://graph.facebook.com/" + self.user_hash["id"].to_s + "/picture"].join("\n<br />")
      
      location = place["location"].to_s
      latitude = location["latitude"].to_s
      longitude = location["longitude"].to_s
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
    if page_hash.nil?
      page_obj = {
        "content" => body,
        "name" => name
      }
      unless page.create(page_obj)
        logger.debug("can't create page")
        return false
      end
      page_hash = page.exist?(name)
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
    unless map.create(map_obj)
      logger.debug("can't create map")
    end
    search_and_add_tag(args, name, body, page_api_location, message)
    return true
  end

  def search_and_add_tag(args, name, body, page_api_location, message)
    tag_names = get_match_tags(message)
    unless tag_names.blank?
      tag_names.each do |tag_name|
        tag_resource_uri = fetch_or_create_tag(args, tag_name)
        if tag_resource_uri
          add_or_new_tag(args, name, page_api_location, tag_resource_uri, tag_name)
        end
      end
    end
  end
  
  def fetch_or_create_tag(args, slug)
    tag = LocalWikiTag.new args
    tag_hash = tag.exist?(slug)
    if tag_hash.nil?
      tag_obj = {
        "name" => slug
      }
      unless tag.create(tag_obj)
        logger.debug "can't create tag"
        return nil
      end
      tag_hash = tag.exist?(slug)
    end
    return tag_hash["resource_uri"]
  end

  def add_or_new_tag(args, page_name, page_api_location, tag_resource_uri, tag_slug)
    page_tags = LocalWikiPageTags.new args
    page_tags_hash = page_tags.exist?(page_name)
    new_tag_uri = "/api/tag/" + tag_slug
    if page_tags_hash.nil?
      page_tags_obj = {
        "page" => page_api_location,
        "tags" => [new_tag_uri]
      }
      unless page_tags.create(page_tags_obj)
        logger.debug "can't create page_tag"
        return nil
      end
    else
      unless page_tags_hash["tags"].include?(tag_resource_uri)
        page_tags_hash["tags"] = unescape_list(page_tags_hash["tags"])
        page_tags_hash["tags"] << new_tag_uri
        unless page_tags.update(page_name, page_tags_hash)
          logger.debug "can't update page_tag"
          return nil
        end
      end
    end
    return true
  end

  def get_match_tags(message)
    tag_names = Array.new
    TAGS.each do |tag|
      r = Regexp.new(tag)
      if r =~ message
        tag_names << tag
      end
    end
    return tag_names
  end

  def unescape_list(tags)
    ret = Array.new
    tags.each do |tag|
      ret << CGI.unescape(tag)
    end
    return ret
  end

end
