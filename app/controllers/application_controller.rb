class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :authenticate_user!
  # allow guest user to be generated prior to authentication
  def authenticate_user!
    current_user
    super
  end

  # add_breadcrumb :index, :root_path

  ###
  # Adapted from
  # https://github.com/plataformatec/devise/wiki/How-To%3a-Create-a-guest-user
  # with modifications to override devise's current_user.
  # if user is logged in, return current_user, else return guest_user
  def current_user
    if super
      if session[:guest_user_id]
        guest_user.destroy
        session[:guest_user_id] = nil
      end
      super
    else
      guest_user
    end
  end
  helper_method :current_user
  # find guest_user object associated with the current session,
  # creating one as needed
  def guest_user
    begin
      # Cache the value the first time it's gotten.
      @cached_guest_user ||= User.find(session[:guest_user_id] ||= create_guest_user.id)
      #sign_in(:user, @cached_guest_user)
    rescue ActiveRecord::RecordNotFound # if session[:guest_user_id] invalid
       session[:guest_user_id] = nil
       guest_user
    end
  end
  # end of adapted from
  ###

  def signed_in?
    @now = DateTime.current().to_time.iso8601
    @jwt = JWT.encode(
        {
            'consumerKey' => ENV["API_CONSUMER"],
            'userId' => current_user.email,
            'issuedAt' => @now,
            'ttl' => 86400
        }, 
        ENV["API_SECRET"]
    )
    gon.current_user = current_user
  end
  helper_method :signed_in?

  def authenticate
    redirect_to root_path, notice: "You need to be signed in" unless signed_in?
  end

  # Copied from Miximize!
  # https://github.com/ryanb/cancan/wiki/Exception-Handling
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end

  private

  ###
  # Adapted from
  # https://github.com/plataformatec/devise/wiki/How-To%3a-Create-a-guest-user
  def create_guest_user
    u = User.create(:firstname => "guest", :lastname => "user", :email => "guest_#{Time.now.to_i}#{rand(99)}@example.com")
    u.save!(:validate => false)
    session[:guest_user_id] = u.id
    # establish guest user credentials
    u.set_roles = ['guest']
    u.rep_group_list << 'public'
    u.save!(:validate => false)
    u
  end
  # end of adapted from
  ###
  
end
