require "open-uri"

class ApiController < ApplicationController
  def call_wiki
    res = open Configurable[:local_wiki_api_endpoint] + params[:path] + "?" + request.query_string
    json = JSON.parse(res.read)
    render json: json
  end
end
