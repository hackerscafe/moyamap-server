Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook, Configurable['facebook_app_id'], Configurable['facebook_app_secret']
end