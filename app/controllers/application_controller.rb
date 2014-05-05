class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :authenticate_user!

  # add_breadcrumb :index, :root_path

  ###
  # Copied from
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
  # find guest_user object associated with the current session,
  # creating one as needed
  def guest_user
    begin
      # Cache the value the first time it's gotten.
      @cached_guest_user ||= User.find(session[:guest_user_id] ||= create_guest_user.id)
      sign_in(:user, @cached_guest_user)

     rescue ActiveRecord::RecordNotFound # if session[:guest_user_id] invalid
       session[:guest_user_id] = nil
       guest_user
     end
  end
  # end of Copied from
  ###
  
  def signed_in?
    @now = DateTime.current().to_time.iso8601
    @current_user = current_user
    # ensure anonymous users can have an email field for the JWT secure token
    @email = ''
    if defined? @current_user and defined? @current_user.email and @current_user.email != ''
      # ensure authorized users get the correct JWT secure token
      @email = @current_user.email
    end
    @jwt = JWT.encode(
        {
            'consumerKey' => ENV["API_CONSUMER"],
            'userId' => @email,
            'issuedAt' => @now,
            'ttl' => 86400
        }, 
        ENV["API_SECRET"]
    )
    gon.current_user = @current_user
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
  # Copied from
  # https://github.com/plataformatec/devise/wiki/How-To%3a-Create-a-guest-user
  def create_guest_user
    u = User.create(:name => "guest", :email => "guest_#{Time.now.to_i}#{rand(99)}@example.com")
    u.save!(:validate => false)
    session[:guest_user_id] = u.id
    u.rep_group_list << "public"
    u.save!(:validate => false)
    u
  end
  # end of Copied from
  ###
end
