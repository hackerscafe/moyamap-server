class User < ActiveRecord::Base
  attr_accessible :fb_token, :hash, :name
end
