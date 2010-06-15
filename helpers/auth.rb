require 'sinatra/base'

module Sinatra 
  module SessionAuth

    module Helpers
      def authorized?
        session[:authorized]
      end

      def authorize!(ip_address)
        unless authorized?
          if ENV['RACK_ENV'] && ENV['RACK_ENV'] == 'production'
            user = ENV['ADMIN_USER']
            pass = ENV['ADMIN_PASS']
          else
            admin_conf = YAML.load(File.read('config/virtualserver/admin.yml'))
            user = admin_conf[:user]
            pass = admin_conf[:pass]
            ips = admin_conf[:allowed_ips]
          end

          if ips.include?(ip_address)
            session[:authorized] = true
          else
            redirect '/login'
          end
        end
      end

      def logout!
        session[:authorized] = false
      end
    end

    def self.registered(app)
      app.helpers SessionAuth::Helpers      
    
      if ENV['RACK_ENV'] && ENV['RACK_ENV'] == 'production'
        user = ENV['ADMIN_USER']
        pass = ENV['ADMIN_PASS']
        ips = ENV['ADMIN_IPS']
      else
        admin_conf = YAML.load(File.read('config/virtualserver/admin.yml'))
        user = admin_conf[:user]
        pass = admin_conf[:pass]
        ips = admin_conf[:allowed_ips]
      end
      
      app.set :username, user
      app.set :password, pass

      app.get '/login' do
        haml :admin_login, :layout => false
      end

      app.post '/login' do
        if params[:user] == options.username && params[:pass] == options.password
          session[:authorized] = true
          redirect '/admin'
        else
          session[:authorized] = false
          redirect '/login'
        end
      end
    end
  end

  register SessionAuth
  helpers Sinatra::SessionAuth
end