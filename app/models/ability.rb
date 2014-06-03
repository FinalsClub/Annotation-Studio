class Ability
  include CanCan::Ability
  include Repertoire::Groups::Ability

  def initialize(user)
    user ||= User.new # guest user (not logged in)

    # If CanCan doesn't find a match for the above, it falls through 
    # to the default abilities provided by Repertoire Groups:
    defaults_for user

    if user.has_role? :admin
      can :manage, :all
    elsif user.has_role? :teacher
      can :create, Document
      # TODO: Teacher can manage his/her own student documents?
      can [:manage, :read, :update], Document, { :user_id => user.id }
      can :destroy, Document, { :user_id => user.id, :published? => false }
    elsif user.has_role? :student
      can :create, Document
      can [:read, :update], Document, { :user_id => user.id }
      can :destroy, Document, { :user_id => user.id, :published? => false }
      # TODO: Possibly clean this up later
      can :read, Document do |tors|
        !(user.rep_group_list & tors.rep_group_list).empty?
      end
    elsif user.has_role? :guest
      can [:read, :index], Document do |tors|
        !(user.rep_group_list & tors.rep_group_list).empty?
      end
    end
  end
end
