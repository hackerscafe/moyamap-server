run "heroku create #{@app_name}"

gem 'pg'
run 'heroku addons:add heroku-postgresql:dev'
file 'config/database.yml', <<-CODE
development: &psql
  adapter: postgresql
  database: showman
  pool: 5
  username: postgres
  password:
  host: localhost

test:
  <<: *psql
  database: showman_test

production:
  <<: *psql
  database: showman_prod
CODE

run 'heroku addons:add sendgrid:starter'
initializer 'mail.rb', <<-CODE
ActionMailer::Base.smtp_settings = {
  :address        => 'smtp.sendgrid.net',
  :port           => '587',
  :authentication => :plain,
  :user_name      => ENV['SENDGRID_USERNAME'],
  :password       => ENV['SENDGRID_PASSWORD'],
  :domain         => 'heroku.com'
}
ActionMailer::Base.delivery_method = :smtp
CODE

git :add => "."
git :commit => "-a -m 'heroku'"

git push heroku master
heroku run rake db:migrate
heroku run rake assets:precompile
