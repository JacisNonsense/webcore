require 'webcore/cdn/extension'
require 'webcore/db/authextension'
require 'webcore/db/auth'
require 'sinatra/cookies'

require 'securerandom'

# Single Sign-On Module
class SSOModule < WebcoreApp()
    enable :sessions
    helpers Sinatra::Cookies
    set :cookie_options, domain: ".#{services[:domains].rootdomain}"

    register ::Webcore::CDNExtension
    register ::Webcore::AuthExtension
    set :root, File.dirname(__FILE__)

    def write_token tok
        cookies[:webcore_token] = Security.encrypt(tok, services[:sso].secret)
    end

    def read_token
        Security.decrypt(cookies[:webcore_token], services[:sso].secret)
    end

    def delete_token
        cookies.delete :webcore_token
    end

    before do
        https!
    end

    get "/" do
        token = Auth::login_token(read_token)
        halt token.to_s if token.is_a?(Symbol)
    end

    get "/login/?" do
        @title = "Login"
        session[:refer] = params[:refer] if params[:refer]
        redirect "/register" if Auth::User.count == 0
        erb :login
    end

    get "/logout/?" do
        Auth::deauth_single(read_token)
        delete_token
        redirect params[:refer] if params[:refer]
        
        redirect "/login"
    end

    get "/register/?" do
        @title = "Register"
        erb :register
    end

    post "/register/?" do
        Auth::create params[:username], params[:email], params[:name], params[:password], (Auth::User.count == 0)
        redirect "/login"
    end

    post "/login" do
        login = params[:login]
        password = params[:password]

        token = Auth::login_password(login, password)
        redirect "/login?error=#{token}" if token.is_a?(Symbol)
        write_token token.id.to_s
        if session[:refer]
            url = session[:refer]
            session.delete :refer
            redirect url
        else
            redirect "/"
        end
    end
end

class SSOService
    attr_accessor :secret
    def initialize
        if ENV['RACK_ENV'] == "development"
            puts "YOU ARE IN DEVELOPMENT MODE."
            puts "SSO SECRETS ARE UNSAFE HERE."
            @secret = "DEADBEEFDEADBEEF" 
        else
            @secret = SecureRandom.hex(64)
        end
    end
end

services[:core].register :sso, SSOService.new