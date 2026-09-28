require 'rails_helper'

RSpec.describe CompanyOutreachJob, type: :job do
  it 'executes CompanyOutreachService successfully' do
    service_double = instance_double(CompanyOutreachService, perform: { sent: 0, processed: 0 })
    expect(CompanyOutreachService).to receive(:new).and_return(service_double)

    CompanyOutreachJob.perform_now
  end
end
