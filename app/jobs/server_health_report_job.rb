class ServerHealthReportJob < ApplicationJob
  queue_as :default

  def perform
    stats = collect_server_stats
    ServerHealthMailer.health_report(stats).deliver_now
  end

  private

  def collect_server_stats
    stats = {}

    # Memory
    meminfo = File.read("/proc/meminfo") rescue ""
    total_kb = meminfo.match(/MemTotal:\s+(\d+)/)&.captures&.first.to_f
    avail_kb = meminfo.match(/MemAvailable:\s+(\d+)/)&.captures&.first.to_f

    if total_kb > 0
      used_kb = total_kb - avail_kb
      stats[:ram_total_gb] = (total_kb / 1024 / 1024).round(1)
      stats[:ram_used_gb]  = (used_kb / 1024 / 1024).round(1)
      stats[:ram_free_gb]  = (avail_kb / 1024 / 1024).round(1)
      stats[:ram_pct]      = ((used_kb / total_kb) * 100).round(1)
    else
      stats[:ram_total_gb] = 0
      stats[:ram_used_gb]  = 0
      stats[:ram_free_gb]  = 0
      stats[:ram_pct]      = 0
    end

    # Load average
    loadavg = File.read("/proc/loadavg").split[0..2].join(", ") rescue "N/A"
    stats[:load_avg] = loadavg

    # Uptime
    uptime_sec = File.read("/proc/uptime").split.first.to_f rescue 0
    days = (uptime_sec / 86400).to_i
    hours = ((uptime_sec % 86400) / 3600).to_i
    stats[:uptime] = "#{days} dias, #{hours} horas"

    # Disk
    df_output = `df -h /`.lines.last rescue ""
    parts = df_output.split
    if parts.size >= 5
      stats[:disk_total] = parts[1]
      stats[:disk_used]  = parts[2]
      stats[:disk_avail] = parts[3]
      stats[:disk_pct]   = parts[4].tr("%", "").to_i
    else
      stats[:disk_total] = "N/A"
      stats[:disk_used]  = "N/A"
      stats[:disk_avail] = "N/A"
      stats[:disk_pct]   = 0
    end

    # AWS CloudWatch CPU Credit Balance
    fetch_cloudwatch_metrics(stats)

    # Docker Container Stats
    fetch_container_stats(stats)

    # Recommendations & Status logic
    recommendations = []
    status_level = :ok
    status_text = "Tudo OK"

    if stats[:cpu_credit_balance].is_a?(Numeric)
      if stats[:cpu_credit_balance] < 50
        status_level = :danger
        status_text = "Créditos CPU Críticos"
        recommendations << "<strong>Créditos de CPU AWS baixíssimos (#{stats[:cpu_credit_balance]}):</strong> Risco iminente de perda extrema de desempenho."
      elsif stats[:cpu_credit_balance] < 200
        status_level = :warning if status_level != :danger
        status_text = "Créditos CPU Baixos"
        recommendations << "<strong>Saldo de créditos de CPU em queda (#{stats[:cpu_credit_balance]}):</strong> Monitorar se o consumo continuará caindo."
      end
    end

    if stats[:disk_pct] >= 85
      status_level = :danger
      status_text = "Disco Crítico"
      recommendations << "<strong>Disco em nível crítico (#{stats[:disk_pct]}%):</strong> Limpar logs ou aumentar volume EBS."
    elsif stats[:disk_pct] >= 70
      status_level = :warning if status_level != :danger
      status_text = "Disco em 70%"
      recommendations << "<strong>Disco em #{stats[:disk_pct]}%:</strong> Acompanhar ocupação para evitar falta de espaço."
    end

    if stats[:ram_pct] >= 90
      status_level = :danger
      status_text = "RAM Crítica"
      recommendations << "<strong>Uso de RAM alto (#{stats[:ram_pct]}%):</strong> Risco de OOM Killer."
    elsif stats[:ram_pct] >= 80
      status_level = :warning if status_level != :danger
      recommendations << "<strong>Uso de RAM elevado (#{stats[:ram_pct]}%):</strong> Monitorar vazamento de memória."
    end

    if stats[:containers].present?
      stats[:containers].each do |c|
        if c[:raw_cpu] && c[:raw_cpu] > 120.0
          status_level = :warning if status_level == :ok
          recommendations << "<strong>Container '#{c[:name]}' com alto processamento (#{c[:cpu_usage]}):</strong> Monitorar picos de uso de CPU."
        end
      end
    end

    stats[:status_level] = status_level
    stats[:status_text]  = status_text
    stats[:recommendations] = recommendations

    stats
  end

  def fetch_cloudwatch_metrics(stats)
    require "aws-sdk-cloudwatch"
    require "net/http"

    instance_id = begin
      uri_token = URI("http://169.254.169.254/latest/api/token")
      req_token = Net::HTTP::Put.new(uri_token)
      req_token["X-aws-ec2-metadata-token-ttl-seconds"] = "60"
      res_token = Net::HTTP.start(uri_token.host, uri_token.port, read_timeout: 2, open_timeout: 2) { |http| http.request(req_token) }
      token = res_token.is_a?(Net::HTTPSuccess) ? res_token.body.to_s.strip : ""

      if token.present?
        uri_id = URI("http://169.254.169.254/latest/meta-data/instance-id")
        req_id = Net::HTTP::Get.new(uri_id)
        req_id["X-aws-ec2-metadata-token"] = token
        res_id = Net::HTTP.start(uri_id.host, uri_id.port, read_timeout: 2, open_timeout: 2) { |http| http.request(req_id) }
        res_id.is_a?(Net::HTTPSuccess) ? res_id.body.to_s.strip : ""
      else
        ""
      end
    rescue
      ""
    end
    instance_id = "i-0489d819554f966da" if instance_id.blank? || !instance_id.start_with?("i-")

    cw = Aws::CloudWatch::Client.new(region: "us-east-2")
    end_time = Time.current
    start_time = end_time - 24.hours

    resp = cw.get_metric_data(
      metric_data_queries: [ {
        id: "cpu_balance",
        metric_stat: {
          metric: {
            namespace: "AWS/EC2",
            metric_name: "CPUCreditBalance",
            dimensions: [ { name: "InstanceId", value: instance_id } ]
          },
          period: 300,
          stat: "Minimum"
        }
      } ],
      start_time: start_time,
      end_time: end_time
    )

    min_balance = resp.metric_data_results.first&.values&.min
    stats[:cpu_credit_balance] = min_balance ? min_balance.round(1) : nil
  rescue => e
    Rails.logger.warn("ServerHealthReportJob: CloudWatch error - #{e.message}")
    stats[:cpu_credit_balance] = nil
  end

  def fetch_container_stats(stats)
    containers_data = []
    socket_path = "/var/run/docker.sock"

    if File.exist?(socket_path) && File.socket?(socket_path)
      unless File.readable?(socket_path)
        Rails.logger.warn("ServerHealthReportJob: Socket /var/run/docker.sock existe mas não tem permissão de leitura para o usuário atual (UID #{Process.uid}).")
      end

      raw_json = read_unix_socket(socket_path, "/containers/json")
      containers = parse_docker_json(raw_json)

      if containers.is_a?(Array)
        containers.each do |c|
          next unless c.is_a?(Hash)

          name = c["Names"]&.first&.sub(%r{^/}, "") || c["Id"].to_s[0..11]
          next if name.include?("-exec-") || name.include?("-assets")

          clean_name = simplify_container_name(name)
          c_id = c["Id"].to_s.gsub(/[^a-zA-Z0-9]/, "")

          stats_json = read_unix_socket(socket_path, "/containers/#{c_id}/stats?stream=false")
          next if stats_json.blank?

          c_stats = parse_docker_json(stats_json)
          next unless c_stats.is_a?(Hash)

          cpu_pct = calculate_cpu_percent(c_stats)
          mem_info = calculate_memory_info(c_stats)

          status = if cpu_pct > 100.0 || mem_info[:pct] > 80.0
                     "🟡 Alto processamento"
          elsif cpu_pct > 50.0 || mem_info[:pct] > 50.0
                     "🟡 Uso Moderado"
          else
                     "🟢 Normal"
          end

          containers_data << {
            name: clean_name,
            cpu_usage: "#{cpu_pct.round(1)}%",
            ram_usage: "#{mem_info[:formatted]} (#{mem_info[:pct].round(1)}%)",
            status: status,
            raw_cpu: cpu_pct,
            raw_ram: mem_info[:pct]
          }
        end
      end
    else
      containers_data = fetch_container_stats_via_cli
    end

    stats[:containers] = containers_data.compact.sort_by { |c| -c[:raw_cpu] }
  rescue => e
    Rails.logger.warn("ServerHealthReportJob: Container stats error - #{e.message}")
    stats[:containers] = []
  end

  def simplify_container_name(name)
    return "kamal-proxy" if name.start_with?("kamal-proxy")

    name.sub(/-(web|job|worker|app|exec).*/i, "")
        .sub(/_(web|job|worker|app|exec).*/i, "")
  end

  def fetch_container_stats_via_cli
    output = `docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"` rescue ""
    return [] if output.blank?

    output.lines.map do |line|
      parts = line.strip.split("\t")
      next if parts.size < 4

      name = simplify_container_name(parts[0])
      cpu_str = parts[1]
      mem_str = parts[2]
      mem_pct_str = parts[3]

      ram_used_part = mem_str.split("/").first&.strip || ""
      cpu_val = cpu_str.tr("%", "").to_f
      mem_pct_val = mem_pct_str.tr("%", "").to_f

      status = if cpu_val > 100.0 || mem_pct_val > 80.0
                 "🟡 Alto processamento"
      elsif cpu_val > 50.0 || mem_pct_val > 50.0
                 "🟡 Uso Moderado"
      else
                 "🟢 Normal"
      end

      {
        name: name,
        cpu_usage: cpu_str,
        ram_usage: "#{ram_used_part} (#{mem_pct_str})",
        status: status,
        raw_cpu: cpu_val,
        raw_ram: mem_pct_val
      }
    end
  end

  def calculate_cpu_percent(c_stats)
    cpu_stats = c_stats["cpu_stats"] || {}
    precpu_stats = c_stats["precpu_stats"] || {}

    total_usage = cpu_stats.dig("cpu_usage", "total_usage").to_f
    pre_total_usage = precpu_stats.dig("cpu_usage", "total_usage").to_f
    cpu_delta = total_usage - pre_total_usage

    system_usage = cpu_stats["system_cpu_usage"].to_f
    pre_system_usage = precpu_stats["system_cpu_usage"].to_f
    system_delta = system_usage - pre_system_usage

    cpus = cpu_stats["online_cpus"].to_f
    cpus = cpu_stats.dig("cpu_usage", "percpu_usage")&.length.to_f if cpus.zero?
    cpus = 1.0 if cpus.zero?

    if system_delta > 0.0 && cpu_delta >= 0.0
      (cpu_delta / system_delta) * cpus * 100.0
    else
      0.0
    end
  end

  def calculate_memory_info(c_stats)
    mem_stats = c_stats["memory_stats"] || {}
    usage = mem_stats["usage"].to_f
    stats_data = mem_stats["stats"] || {}
    cache = (stats_data["inactive_file"] || stats_data["total_inactive_file"] || stats_data["cache"]).to_f
    used = usage - cache
    used = usage if used < 0

    limit = mem_stats["limit"].to_f
    pct = limit > 0 ? (used / limit) * 100.0 : 0.0

    formatted = if used >= 1_073_741_824
                  "#{(used / 1_073_741_824.0).round(2)} GiB"
    else
                  "#{(used / 1_048_576.0).round(0)} MiB"
    end

    { used_bytes: used, limit_bytes: limit, pct: pct, formatted: formatted }
  end

  def read_unix_socket(socket_path, path)
    require "socket"
    socket = UNIXSocket.new(socket_path)
    # Requisitar via HTTP/1.0 evita que o Docker Engine envie Transfer-Encoding: chunked
    socket.write("GET #{path} HTTP/1.0\r\nHost: localhost\r\nAccept: application/json\r\nConnection: close\r\n\r\n")
    response = socket.read
    socket.close
    response.to_s.split("\r\n\r\n", 2).last || ""
  rescue => e
    Rails.logger.warn("ServerHealthReportJob: UNIX socket error (#{path}) - #{e.class}: #{e.message}")
    ""
  end

  def parse_docker_json(raw_response)
    return [] if raw_response.blank?

    cleaned = decode_chunked(raw_response)
    JSON.parse(cleaned)
  rescue JSON::ParserError => e
    Rails.logger.warn("ServerHealthReportJob: JSON parse error - #{e.message}")
    []
  end

  def decode_chunked(str)
    return str unless str =~ /\A[0-9a-fA-F]+\r\n/

    result = +""
    scanner = str.dup
    while scanner.present?
      parts = scanner.split("\r\n", 2)
      break if parts.size < 2

      len_hex = parts[0].split(";").first.strip
      chunk_len = len_hex.to_i(16) rescue 0
      break if chunk_len.zero?

      rest = parts[1]
      result << rest[0...chunk_len]
      scanner = rest[chunk_len + 2..] || ""
    end

    result.empty? ? str : result
  end
end
