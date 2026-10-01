module App
  class CompaniesController < BaseController
    before_action :set_company, only: [ :edit, :update, :claim, :verify, :submit_verification, :soft_delete, :purge_photo, :update_card, :remove_card, :cancel_subscription, :subscribe ]
    before_action :ensure_approved_company!, only: [ :edit, :update, :purge_photo, :update_card, :remove_card, :cancel_subscription, :subscribe ]


    def new
      if current_user.company.present?
        redirect_to app_root_path, alert: "Você já possui um perfil de empresa associado." and return
      end
      @company = Company.new
      @states = State.order(:name)
      @categories = Category.order(:name)
    end

    def create
      if current_user.company.present?
        redirect_to app_root_path, alert: "Você já possui um perfil de empresa associado." and return
      end

      new_photos = Array(params.dig(:company, :photos)).reject(&:blank?)
      c_params = company_params.except(:photos)

      # Verifica se o CNPJ já existe na base de dados
      raw_cnpj = c_params[:cnpj].to_s.strip
      clean_cnpj = raw_cnpj.gsub(/\D/, "")

      existing_company = nil
      if clean_cnpj.present?
        existing_company = Company.find_by(cnpj: clean_cnpj)
        existing_company ||= Company.find_by(cnpj: raw_cnpj)
        existing_company ||= Company.where("replace(replace(replace(cnpj, '.', ''), '/', ''), '-', '') = ?", clean_cnpj).first
      end

      if existing_company.present?
        if existing_company.user_id.present? && existing_company.user_id != current_user.id && !existing_company.unclaimed?
          @company = Company.new(c_params)
          @states = State.order(:name)
          @categories = Category.order(:name)
          flash.now[:alert] = "O CNPJ informado já está vinculado a outra conta cadastrada. Se você é o titular desta oficina, entre em contato com nosso suporte para comprovação."
          render :new, status: :unprocessable_entity and return
        else
          # Vincula a empresa existente à conta do usuário
          existing_company.user = current_user
          existing_company.claim_status = :pending
          existing_company.claimed_at = Time.current
          existing_company.claim_expiration_date = 5.days.from_now

          # Atualiza os dados de contato informados pelo usuário
          existing_company.phone_1 = c_params[:phone_1] if c_params[:phone_1].present?
          existing_company.phone_1_whatsapp = c_params[:phone_1_whatsapp] if c_params.key?(:phone_1_whatsapp)
          existing_company.phone_2 = c_params[:phone_2] if c_params[:phone_2].present?
          existing_company.phone_2_whatsapp = c_params[:phone_2_whatsapp] if c_params.key?(:phone_2_whatsapp)
          existing_company.website = c_params[:website] if c_params[:website].present?
          existing_company.description = c_params[:description] if c_params[:description].present?
          existing_company.save(validate: false)

          existing_company.photos.attach(new_photos) if new_photos.present?
          current_user.convert_to_company! if current_user.role != "company"
          AdminNotificationMailer.company_claim_notification(existing_company, current_user, "reivindicação via cadastro").deliver_later
          redirect_to verify_app_company_path(existing_company), notice: "Identificamos que sua oficina mecânica já possuía cadastro em nossa base oficial da Receita Federal! O perfil foi vinculado à sua conta com sucesso. Agora, envie a documentação para validação." and return
        end
      end

      @company = Company.new(c_params)
      @company.user = current_user
      @company.email = current_user.email
      @company.claim_status = :pending
      @company.claimed_at = Time.current
      @company.claim_expiration_date = 5.days.from_now
      @company.status = "ATIVA" if @company.status.blank?

      if @company.save
        @company.photos.attach(new_photos) if new_photos.present?
        current_user.convert_to_company! if current_user.role != "company"
        AdminNotificationMailer.company_claim_notification(@company, current_user, "novo cadastro").deliver_later
        redirect_to verify_app_company_path(@company), notice: "Perfil criado com sucesso. Agora, envie a documentação para verificação."
      else
        @states = State.order(:name)
        @categories = Category.order(:name)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @states = State.order(:name)
      @cities = @company.state&.cities&.order(:name) || []
      @neighborhoods = @company.city&.neighborhoods&.order(:name) || []
      @categories = Category.order(:name)
    end

    def update
      new_photos = Array(params.dig(:company, :photos)).reject(&:blank?)
      c_params = company_params.except(:photos)

      total_photos = @company.photos.count + new_photos.count
      if total_photos > @company.photo_limit
        redirect_to edit_app_company_path(@company), alert: "Você ultrapassou o limite de #{@company.photo_limit} fotos ativas do seu plano (#{@company.free_plan? ? 'Plano Free: 3 fotos' : 'Plano Premium: 20 fotos'})." and return
      end

      if @company.update(c_params)
        if new_photos.present?
          @company.photos.attach(new_photos)
        end


        if @company.approved? || @company.document_submitted_at.present?
          redirect_to app_root_path, notice: "Perfil atualizado com sucesso!"
        else
          redirect_to verify_app_company_path(@company), notice: "Dados salvos com sucesso! Por favor, envie os documentos para verificação."
        end
      else
        @states = State.order(:name)
        @cities = @company.state&.cities&.order(:name) || []
        @neighborhoods = @company.city&.neighborhoods&.order(:name) || []
        @categories = Category.order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    def purge_photo
      photo = @company.photos.find_by(id: params[:photo_id])
      if photo
        photo.purge
        redirect_to edit_app_company_path(@company), notice: "Foto removida com sucesso."
      else
        redirect_to edit_app_company_path(@company), alert: "Foto não encontrada."
      end
    end

    def claim
      if current_user.company.present?
        redirect_to app_root_path, alert: "Você já possui um perfil de empresa associado." and return
      end

      if @company.user.present? || !@company.unclaimed?
        redirect_to app_root_path, alert: "Este perfil já foi reivindicado por outro usuário." and return
      end

      @company.update!(
        user: current_user,
        claim_status: :pending,
        claimed_at: Time.current,
        claim_expiration_date: 5.days.from_now
      )
      current_user.convert_to_company! if current_user.role != "company"
      AdminNotificationMailer.company_claim_notification(@company, current_user, "reivindicação").deliver_later

      redirect_to verify_app_company_path(@company), notice: "Perfil reivindicado! Envie os documentos para verificação e aprovação do perfil em até 5 dias."
    end

    def verify
    end

    def submit_verification
      document = params[:document_proof]
      selfie = params[:selfie_proof]

      if document.blank? || selfie.blank?
        flash.now[:alert] = "Você precisa enviar o comprovante com foto (ou contrato social) e a selfie do responsável segurando o documento."
        render :verify, status: :unprocessable_entity and return
      end

      @company.document_proof.attach(document)
      @company.selfie_proof.attach(selfie)

      @company.update!(
        document_proof_url: @company.document_proof_display_url,
        selfie_proof_url: @company.selfie_proof_display_url,
        document_submitted_at: Time.current,
        claim_status: :pending
      )
      AdminNotificationMailer.company_claim_notification(@company, current_user, "envio de documentos").deliver_later

      redirect_to app_root_path, notice: "Documentos enviados com sucesso! A análise manual será feita em até 5 dias úteis."
    end

    def soft_delete
      user = current_user
      company = @company

      if params[:confirm_text].blank? || params[:confirm_text].strip.upcase != "EXCLUIR"
        redirect_to app_root_path, alert: "Para confirmar a exclusão irreversível, você deve digitar EXCLUIR no modal de confirmação." and return
      end

      company.soft_delete! if company.present?
      sign_out(user) if user_signed_in?
      user.destroy! if user.present?

      redirect_to root_path, notice: "Sua conta e o perfil da empresa foram excluídos permanentemente em conformidade com a LGPD. Ação irreversível concluída."
    end

    def update_card
      pm_id = params[:stripe_payment_method_id].presence || params[:payment_method_id].presence
      card_brand = params[:card_brand].presence || "visa"
      card_last4 = params[:card_last4].presence || "4242"

      if params[:card_number].present?
        digits = params[:card_number].to_s.gsub(/\D/, "")
        card_last4 = digits[-4..-1] if digits.length >= 4
      end

      @company.update_card_details!(pm_id, card_brand, card_last4)
      redirect_to app_root_path, notice: "Cartão de crédito registrado com sucesso!"
    rescue StandardError => e
      redirect_to app_root_path, alert: "Erro ao salvar cartão: #{e.message}"
    end

    def remove_card
      if @company.can_remove_card?
        @company.remove_card!
        redirect_to app_root_path, notice: "Cartão de crédito removido com sucesso."
      else
        redirect_to app_root_path, alert: "Sua empresa possui um plano ativo pago e não pode remover o cartão de crédito antes de cancelar o plano."
      end
    rescue StandardError => e
      redirect_to app_root_path, alert: "Erro ao remover cartão: #{e.message}"
    end

    def cancel_subscription
      @company.cancel_active_subscription!
      redirect_to app_root_path, notice: "Plano cancelado com sucesso. Cobrança proporcional processada."
    rescue StandardError => e
      redirect_to app_root_path, alert: "Erro ao cancelar plano: #{e.message}"
    end

    def subscribe
      plan_slug = params[:plan_slug]
      unless %w[free premium].include?(plan_slug)
        redirect_to pricing_path, alert: "Plano indisponível ou inválido selecionado." and return
      end


      if @company.card_last4.blank? && plan_slug != "free"
        redirect_to app_root_path(open_card_modal: true), alert: "Para assinar o Plano #{plan_slug.titleize}, por favor cadastre seu cartão de crédito primeiro em seu painel." and return
      end

      begin
        @company.subscribe_to_plan!(plan_slug)
        redirect_to app_root_path, notice: "🎉 Parabéns! Seu Plano #{plan_slug.titleize} foi ativado com sucesso! Todos os recursos foram liberados no seu perfil."
      rescue Stripe::CardError => e
        error_msg = case e.code
        when "insufficient_funds"
                      "Saldo insuficiente no cartão de crédito fornecido."
        when "card_declined"
                      "O cartão de crédito foi recusado pelo banco emissor."
        when "expired_card"
                      "O cartão de crédito está vencido."
        when "incorrect_cvc"
                      "O código de segurança (CVC) do cartão está incorreto."
        else
                      e.message
        end
        redirect_to pricing_path, alert: "Erro no pagamento: #{error_msg} (Código: #{e.code || 'card_error'}). Por favor, verifique seu cartão ou entre em contato com nosso suporte se tiver dúvidas."
      rescue StandardError => e
        redirect_to pricing_path, alert: "Erro ao processar assinatura: #{e.message}. Por favor, entre em contato com nosso suporte caso tenha dúvidas."
      end
    end



    def cities
      state = State.find(params[:state_id])
      render json: state.cities.order(:name).select(:id, :name)
    end

    def neighborhoods
      city = City.find(params[:city_id])
      render json: city.neighborhoods.order(:name).select(:id, :name)
    end

    private

    def set_company
      if action_name == "claim"
        @company = Company.find(params[:id])
      else
        @company = current_user.company || Company.find(params[:id])
        if @company.user != current_user
          redirect_to app_root_path, alert: "Acesso não autorizado."
        end
      end
    end

    def ensure_approved_company!
      unless @company.approved?
        if @company.document_submitted_at.blank?
          redirect_to verify_app_company_path(@company), alert: "Você precisa enviar a documentação e ter a solicitação aprovada antes de editar as informações do perfil."
        else
          redirect_to app_root_path, alert: "Seu perfil de empresa está em análise. A edição de informações só estará disponível após a aprovação da verificação."
        end
      end
    end

    def company_params
      params.require(:company).permit(
        :trade_name, :legal_name, :cnpj, :cnae_principal, :email,
        :phone_1, :phone_1_whatsapp, :phone_2, :phone_2_whatsapp,
        :description, :business_hours, :website, :logo, :logo_url,
        :state_id, :city_id, :neighborhood_id, :street, :number, :complement, :zip_code,
        photos: [], category_ids: []
      )
    end
  end
end
