class DevelopmentMailInterceptor
  def self.delivering_email(message)
    if Rails.env.development? || ENV["FORCE_DEV_INTERCEPTOR"] == "true"
      original_to = Array(message.to).join(", ")
      message.subject = "[DEV -> #{original_to}] #{message.subject}"
      message.to = [ "jmfutrica@gmail.com" ]
    end
  end
end

if Rails.env.development?
  ActionMailer::Base.register_interceptor(DevelopmentMailInterceptor)
end
