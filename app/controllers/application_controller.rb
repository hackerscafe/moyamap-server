class ApplicationController < ActionController::Base
  protect_from_forgery

  def koala
    @koala ||= Koala::Facebook::API.new(params[:token] || current_user.fb_token)
  end
end
