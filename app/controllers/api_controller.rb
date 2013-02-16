require "open-uri"

class ApiController < ApplicationController
  def call_wiki
    uri = URI(Configurable[:local_wiki_api_endpoint] + params[:path] + "?api_key=#{Configurable[:local_wiki_api_key]}&" + request.query_string)
    http = Net::HTTP.new(uri.host)
    res = http.send(request.request_method.downcase, uri.request_uri)
    json = JSON.parse(res.body)
    render json: json
  end
end
