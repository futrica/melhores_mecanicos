class Users::RegistrationsController < Devise::RegistrationsController
  protected

  def update_resource(resource, params)
    # O e-mail é a chave de acesso da conta e não pode ser alterado diretamente
    params.delete(:email)

    if resource.provider.present?
      # Usuários autenticados via OAuth (Google) não possuem senha local
      params.delete(:current_password)
      if params[:password].blank?
        params.delete(:password)
        params.delete(:password_confirmation)
      end
      resource.update_without_password(params)
    elsif params[:password].blank? && params[:password_confirmation].blank?
      # Usuários comuns atualizando apenas dados cadastrais (nome, telefone)
      params.delete(:current_password)
      params.delete(:password)
      params.delete(:password_confirmation)
      resource.update_without_password(params)
    else
      # Usuários alterando a própria senha necessitam da senha atual por segurança
      resource.update_with_password(params)
    end
  end

  def after_update_path_for(resource)
    app_root_path
  end
end
