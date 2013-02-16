class User < ActiveRecord::Base
  serialize hash, Hash
end
