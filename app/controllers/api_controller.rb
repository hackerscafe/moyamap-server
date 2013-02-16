require "open-uri"

class ApiController < ApplicationController
  def call_wiki
    uri = URI(Configurable[:local_wiki_api_endpoint] + params[:path])
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
end
