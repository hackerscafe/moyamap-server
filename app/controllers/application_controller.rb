class ApplicationController < ActionController::Base
  protect_from_forgery

  def current_user
    @current_user ||= User.find_by_id(session[:user_id])
  end
  def koala
    @koala ||= Koala::Facebook::API.new(params[:token] || current_user.fb_token)
  end
end
