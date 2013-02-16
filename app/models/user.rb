class User < ActiveRecord::Base
  serialize :user_hash, Hash
end
