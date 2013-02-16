class UserSessionsController < ApplicationController
  # GET /user_sessions/1
  # GET /user_sessions/1.json
  def show
  end

  # GET /user_sessions/new
  # GET /user_sessions/new.json
  def new
  end

  # POST /user_sessions
  # POST /user_sessions.json
  def create
    @user = User.find_by_fb_token(params[:token])
    unless @user
      profile = koala.get_object("me")
      @user = User.new(name: profile.username, fb_token: params[:token])
      @user.hash = profile.to_hash
    end

    respond_to do |format|
      if @user.persisted?
        format.html { redirect_to @user, notice: 'User session was successfully created.' }
        format.json { render json: {status: :logged_in, user: @user}, status: :created }
      else
        @user.save!
        format.html { redirect_to @user, notice: 'User was successfully created.' }
        format.json { render json: {status: :created, user: @user}, status: :created }
      end
    end

    session[:user_id] = @user.id
  end

  # DELETE /user_sessions/1
  # DELETE /user_sessions/1.json
  def destroy
    reset_session

    respond_to do |format|
      format.html { redirect_to root_url }
      format.json { head :no_content }
    end
  end
end
