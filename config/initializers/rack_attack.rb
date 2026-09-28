class Rack::Attack
  # Usar armazenamento em memória para rastreamento de requisições
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Limitar a rota /busca a 50 requisições por minuto por IP
  throttle("search/ip", limit: 50, period: 1.minute) do |req|
    if req.path == "/busca" && req.get?
      req.env["HTTP_CF_CONNECTING_IP"] || req.env["HTTP_X_FORWARDED_FOR"]&.split(",")&.last&.strip || req.ip
    end
  end

  # Resposta HTTP 429 quando o limite for excedido
  self.throttled_responder = lambda do |req|
    match_data = req.env["rack.attack.match_data"]
    retry_after = match_data ? match_data[:period] : 60
    [
      429,
      { "Content-Type" => "text/html; charset=utf-8", "Retry-After" => retry_after.to_s },
      [ "<html><body><h1>429 - Limite de Buscas Excedido</h1><p>Você realizou muitas buscas em um curto intervalo. Por favor, aguarde 1 minuto para tentar novamente.</p></body></html>" ]
    ]
  end
end
