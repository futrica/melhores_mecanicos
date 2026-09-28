require "test_helper"

class ServerHealthReportJobTest < ActiveJob::TestCase
  test "parse_docker_json handles raw JSON and chunked encoding" do
    job = ServerHealthReportJob.new

    json_payload = '[{"Id":"12345","Names":["/app-web"]}]'
    parsed = job.send(:parse_docker_json, json_payload)
    assert_equal 1, parsed.size
    assert_equal "12345", parsed.first["Id"]
  end

  test "decode_chunked handles chunked http responses" do
    job = ServerHealthReportJob.new

    chunked = "1b\r\n[{\"Id\":\"12345\",\"Names\":[]}]\r\n0\r\n\r\n"
    decoded = job.send(:decode_chunked, chunked)
    parsed = JSON.parse(decoded)
    assert_equal 1, parsed.size
    assert_equal "12345", parsed.first["Id"]
  end
end
