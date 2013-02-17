# -*- coding: utf-8 -*-
require 'rest_client'
require 'json'
require 'cgi'

class LocalWikiClientBase
  
  def initialize args
    @base_url = args[:base_url] or raise ArgumentError, "must need :base_url"
    @user_name = args[:user_name]
    @api_key = args[:api_key]
  end
  
  def api_path
  end
  
  
  def headers
    _headers = {}
    _authorization_header = authorization_header
    unless _authorization_header.nil?
      _headers[:authorization] = _authorization_header
    end
    _headers[:content_type] = :json
    _headers[:accept] = :json
    return _headers
  end

  def exist?(page_or_id)
    begin
      response = RestClient.get @base_url + api_path + escape_and_get_back_slash(page_or_id), headers
      if response.code == 200
        return JSON.parse(response.to_str)
      end
    rescue => e
      puts e
    end
    return nil
  end

  def exist_with_name?(name)
    begin
      response = RestClient.get @base_url + api_path + "?name__iexact=" + escape_and_get_back_slash(name), headers
      if response.code == 200
        json = JSON.parse(response.to_str)
        return json["objects"][0]
      end
    rescue => e
      puts e
    end
    return nil
  end

  def create(obj)
    raise RuntimeError, "must set user_name and api_key" unless can_post?
    puts JSON.dump(obj)
    begin
      response = RestClient.post @base_url + api_path, JSON.dump(obj), headers
      if response.code == 201
        return true
      end
    rescue => e
      puts "Unable create because #{e.message}"
    end
    return false
  end

  def update(page_or_id, obj)
    raise RuntimeError, "must set user_name and api_key" unless can_post?
    puts JSON.dump(obj)
    begin
      response = RestClient.put @base_url + api_path + escape_and_get_back_slash(page_or_id), JSON.dump(obj), headers
      if response.code == 204
        return true
      end
    rescue => e
      puts "Unable update because #{e.message}"
    end
    return false
  end

  def delete(page_or_id)
    raise RuntimeError, "must set user_name and api_key" unless can_post?
    begin
      response = RestClient.delete @base_url + api_path + escape_and_get_back_slash(page_or_id), headers
      if response.code == 204
        return true
      end
    rescue => e
      puts "Unable delete because #{e.message}"
    end
    return false
  end

  def search_with_auth(objs)
    raise RuntimeError, "must set user_name and api_key" unless can_post?
    begin
      response = RestClient.get @base_url + api_path + make_query(objs), headers
      if response.code == 200
        return JSON.parse(response.to_str)
      end
    rescue => e
      puts "Can't search because #{e.message}"
    end
    return nil
  end

  def get(path)
    begin
      response = RestClient.get @base_url + path, headers
      if response.code == 200
        return JSON.parse(response.to_str)
      end
    rescue => e
      puts "Can't get because #{e.message}"
    end
    return nil
  end

  private

  def make_query(objs)
    queries = Array.new
    objs.each do |obj|
      queries << "#{obj[0]}__#{obj[1]}=" + CGI.escape(obj[2])
    end
    query = queries.join("&")
    if query
      return "?" + query
    end
    return ""
  end

  def can_post?
    @user_name.present? && @api_key.present?
  end

  def authorization_header
    "ApiKey #{@user_name}:#{@api_key}" if can_post?
  end

  def escape_and_get_back_slash(page_or_id)
    CGI.escape(page_or_id).gsub("%2F", "/")
  end
end

class LocalWikiPage < LocalWikiClientBase

  def api_path
    "/api/page/"
  end

end

class LocalWikiFile < LocalWikiClientBase

  def api_path
    "/api/file/"
  end
  
  def upload(file_path, file_name, slug)
    
    begin
      response = RestClient.post @base_url + api_path, {:file => File.new(file_path, 'rb'), :name => file_name, :slug => slug}, headers
    rescue => e
      puts e
    end
  end
end

class LocalWikiMap < LocalWikiClientBase
  
  def api_path
    "/api/map/"
  end

end

# for custom api
class LocalWikiUsersWithKey < LocalWikiClientBase
  
  def api_path
    "/api/users_with_apikey/"
  end

end

# for custom api
class LocalWikiApiKey < LocalWikiClientBase
  
  def api_path
    "/api/api_key/"
  end

end

class LocalWikiTag < LocalWikiClientBase
  
  def api_path
    "/api/tag/"
  end

end

class LocalWikiPageTags < LocalWikiClientBase
  
  def api_path
    "/api/page_tags/"
  end

end

class LocalWikiUtil
  def self.fetch_or_create_tag(args, name)
    tag = LocalWikiTag.new args
    tag_hash = tag.exist_with_name?(name)
    if tag_hash.nil?
      tag_obj = {
        "name" => name
      }
      unless tag.create(tag_obj)
        p "can't create tag"
        return nil
      end
      tag_hash = tag.exist_with_name?(name)
    end
    return tag_hash
  end

  def self.add_or_new_tag(args, page_slug, page_api_location, tag_resource_uri, tag_slug)
    page_tags = LocalWikiPageTags.new args
    page_tags_hash = page_tags.exist?(page_slug)
    new_tag_uri = "/api/tag/" + tag_slug
    if page_tags_hash.nil?
      page_tags_obj = {
        "page" => page_api_location,
        "tags" => [new_tag_uri]
      }
      unless page_tags.create(page_tags_obj)
        p "can't create page_tag"
        return nil
      end
    else
      unless page_tags_hash["tags"].include?(tag_resource_uri)
        page_tags_hash["tags"] = unescape_list(page_tags_hash["tags"])
        page_tags_hash["tags"] << new_tag_uri
        unless page_tags.update(page_slug, page_tags_hash)
          p "can't update page_tag"
          return nil
        end
      end
    end
    return true
  end
  
  def self.unescape_list(tags)
    ret = Array.new
    tags.each do |tag|
      ret << CGI.unescape(tag)
    end
    return ret
  end
  

end
