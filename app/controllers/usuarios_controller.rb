require 'sal7711_gen/concerns/controllers/usuarios_controller'

class UsuariosController < Msip::ModelosController

  # Sin definir control de acceso por ser requerido por no autenticados
  
  include Sal7711Gen::Concerns::Controllers::UsuariosController    
end
