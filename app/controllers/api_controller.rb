# -*- coding: utf-8 -*-
require "open-uri"
require "localwiki_client"

class ApiController < ApplicationController
  def call_wiki
    uri = URI(Configurable[:local_wiki_api_endpoint] + params[:path] + "?" + request.query_string)
    case request.request_method
    when "GET"
      req = Net::HTTP::Get.new(uri.request_uri)
    when "POST"
      req = Net::HTTP::Post.new(uri.request_uri)
      req["Authorization"] = "ApiKey apiuser:#{Configurable[:local_wiki_api_key]}"
      req["Content-Length"] = request.content_length
      req["Content-Type"] = "application/json"
      req.body_stream = request.body
    end

    res = Net::HTTP.new(uri.host).request(req)
    json = res.body.present? ? JSON.parse(res.body) : {}
    render json: json, status: res.code
  end

  def tag_to_page
    page_name = params[:page]
    tag_name = params[:tag]
    args = {
      :base_url => Configurable[:local_wiki_server],
      :user_name => "apiuser",
      :api_key => Configurable[:local_wiki_api_key]
    }
    page = LocalWikiPage.new args
    page_hash = page.exist_with_name?(page_name)
    if page_hash.nil?
      render json: {"status" => "NG", "message" => "ページがみつかりません"}, status: "500"
      return
    end
    tag_hash = LocalWikiUtil.fetch_or_create_tag(args, tag_name)
    if tag_hash.nil?
      render json: {"status" => "NG", "message" => "タグが作成できません"}, status: "500"
      return
    end
    page_api_location = page_hash["resource_uri"]
    page_slug = page_hash["slug"]
    tag_resource_uri = tag_hash["resource_uri"]
    tag_slug = tag_hash["slug"]
    if LocalWikiUtil.add_or_new_tag(args, page_slug, page_api_location, tag_resource_uri, tag_slug)
      render json: {"status" => "OK", "message" => "タグを作成しました"}, status: "204"
      return
    end
    render json: {"status" => "NG", "message" => "タグ付に失敗しました"}, status: "500"
    return
  end
    
end
