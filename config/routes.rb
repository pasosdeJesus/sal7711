Rails.application.routes.draw do

  rutarel = ENV.fetch('RUTA_RELATIVA', 'sal7711/')
  scope rutarel do 
    devise_scope :usuario do
      get 'sign_out' => 'devise/sessions#destroy'
      get 'salir' => 'devise/sessions#destroy',
        as: :terminar_sesion
      post 'usuarios/iniciar_sesion', to: 'devise/sessions#create'
      get 'usuarios/iniciar_sesion', to: 'devise/sessions#new',
        as: :iniciar_sesion

      # El siguiente para superar mala generación del action en el formulario
      # cuando se autentica mal y esta montado no en / (genera 
      # /puntomontaje/puntomontaje/usuarios/sign_in )
      if (Rails.configuration.relative_url_root != '/') 
        ruta = File.join(Rails.configuration.relative_url_root, 
                         'usuarios/sign_in')
        post ruta, to: 'devise/sessions#create'
        get  ruta, to: 'devise/sessions#new'
      end
    end
    devise_for :usuarios, :skip => [:registrations], module: :devise
    as :usuario do
      get 'usuarios/edit' => 'devise/registrations#edit', 
        :as => 'editar_registro_usuario'    
      put 'usuarios/:id' => 'devise/registrations#update', 
        :as => 'registro_usuario'            
    end
    resources :usuarios, path_names: { new: 'nuevo', edit: 'edita' } 

    root to: 'msip/hogar#index'
  end

  mount Msip::Engine, at: rutarel, as: 'msip'
  mount Sal7711Gen::Engine, at: rutarel, as: 'sal7711_gen'
end
