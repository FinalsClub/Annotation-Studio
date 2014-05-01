AnnotationStudio::Application.routes.draw do
  devise_for :users

  resources :documents
  resources :users, only: [:show, :edit]

  # routes exposed anonymously
  get 'annotations', to: 'annotations#index'
  get 'annotations/:id', to: 'annotations#show'

  # routes which require authenticated login
  authenticated :user do
    root :to => "users#show"
    get 'dashboard', to: 'users#show', as: :dashboard
    get 'groups', to: 'groups#index'
    get 'groups/:id', to: 'groups#show'
  end

  unauthenticated :user do
    devise_scope :user do
      get "/" => "devise/sessions#new"
    end
  end

  ActiveAdmin.routes(self)
  devise_for :admin_users, ActiveAdmin::Devise.config
end
