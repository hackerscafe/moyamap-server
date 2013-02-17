# -*- coding: utf-8 -*-
require 'localwiki_client'
require 'net/https'

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
          checkin_id: checkin["id"].to_s,
          location_name: place["name"].to_s,
          message: checkin["message"].to_s,
          time: checkin["created_time"].to_s,
          user_name: self.user_hash["name"].to_s,
          user_id: self.user_hash["id"].to_s,
          picture_url: "https://graph.facebook.com/#{self.user_hash["id"]}/picture",
          friend: ""
      }.to_yaml + "</pre>"

      location = place["location"]
      latitude = location["latitude"]
      longitude = location["longitude"]
      message = checkin["message"].to_s
      post_to_localwiki(name, body, latitude, longitude, message)
    end
    return true
  end

  def crawl_friend_checkins
    base_uri = "https://graph.facebook.com/fql?q="
    query = '{"checkin": "select checkin_id, message, author_uid, target_type, target_id, page_id, timestamp from checkin where author_uid IN (SELECT uid2 FROM friend WHERE uid1 = ' + self.user_hash["id"] + ') and message != ' + "''" + ' order by timestamp desc limit 1", "user": "select username, name, id, pic from profile where id in (select author_uid from #checkin)", "page": "select name, page_id, location from page where page_id in (select page_id from #checkin)"}'
    query = CGI.escape(query)
    uri = URI(base_uri + query + "&access_token=" + self.fb_token)
    req = Net::HTTP::Get.new(uri.request_uri)
    https = Net::HTTP.new(uri.host, 443)
    https.use_ssl = true
    https.verify_mode = OpenSSL::SSL::VERIFY_PEER
    https.ca_path = '/etc/ssl/certs' if File.exists?('/etc/ssl/certs') # Ubuntu
    https.ca_file = '/opt/local/share/curl/curl-ca-bundle.crt' if File.exists?('/opt/local/share/curl/curl-ca-bundle.crt') # Mac OS X
    res = https.request(req)
    
    json = res.body.present? ? JSON.parse(res.body) : {}
    logger.debug(json)
    checkins = nil
    users = nil
    pages = nil
    json["data"].each do |data|
      logger.debug(data)
      case data["name"]
      when "checkin"
        checkins = data["fql_result_set"]
      when "user"
        users = data["fql_result_set"]
      when "page"
        pages = data["fql_result_set"]
      end
    end
    checkins.each do |checkin|
      #place = checkin["place"]
      author_uid = checkin["author_uid"]
      page_id = checkin["page_id"]
      user = get_obj(users, "id", author_uid)
      page = get_obj(pages, "page_id", page_id)
      
      name = user["username"] + "/" + page_id.to_s
      body = "<pre>" + {
          checkin_id: checkin["checkin_id"].to_s,
          location_name: page["name"].to_s,
          message: checkin["message"].to_s,
          time: Time.at(checkin["timestamp"]).to_s,
          user_name: user["name"].to_s,
          user_id: user["id"].to_s,
          picture_url: "https://graph.facebook.com/#{user["id"]}/picture",
          friend: self.name
      }.to_yaml + "</pre>"

      location = page["location"]
      latitude = location["latitude"]
      longitude = location["longitude"]
      message = checkin["message"].to_s
      post_to_localwiki(name, body, latitude, longitude, message)
    end
    return true
  end


  private

  def get_obj(array, key, value)
    array.each do |a|
      if a[key].to_s == value.to_s
        return a
      end
    end
    return nil
  end

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
