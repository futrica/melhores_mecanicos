# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, "https://*.google-analytics.com", "https://*.googletagmanager.com", "https://pagead2.googlesyndication.com"
    policy.object_src  :none

    # Scripts: self + Google Analytics + Google AdSense + Google OAuth + Stripe + inline scripts
    policy.script_src  :self, :https, :unsafe_inline, :unsafe_eval,
                       "https://accounts.google.com",
                       "https://www.googletagmanager.com",
                       "https://*.googletagmanager.com",
                       "https://*.google-analytics.com",
                       "https://pagead2.googlesyndication.com",
                       "https://googleads.g.doubleclick.net",
                       "https://tpc.googlesyndication.com",
                       "https://js.stripe.com"

    # Estilos: self + unsafe_inline necessário para Turbo/Stimulus e AdSense
    policy.style_src   :self, :https, :unsafe_inline

    # Conexões permitidas (fetch, XHR, beacons do Analytics e AdSense + Stripe API)
    policy.connect_src :self, :https,
                       "https://accounts.google.com",
                       "https://*.google-analytics.com",
                       "https://*.analytics.google.com",
                       "https://*.googletagmanager.com",
                       "https://stats.g.doubleclick.net",
                       "https://pagead2.googlesyndication.com",
                       "https://googleads.g.doubleclick.net",
                       "https://*.adtrafficquality.google",
                       "https://api.stripe.com"

    # Frames: permitir Google OAuth, AdSense, DoubleClick e Stripe iFrames
    policy.frame_src   :self,
                       "https://accounts.google.com",
                       "https://googleads.g.doubleclick.net",
                       "https://*.doubleclick.net",
                       "https://tpc.googlesyndication.com",
                       "https://pagead2.googlesyndication.com",
                       "https://*.adtrafficquality.google",
                       "https://www.google.com",
                       "https://js.stripe.com",
                       "https://hooks.stripe.com"

    # Formulários: apenas para o próprio domínio e Google OAuth
    policy.form_action :self, "https://accounts.google.com"
  end
end
