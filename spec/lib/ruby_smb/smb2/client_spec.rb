require 'support/mock_socket_dispatcher'

RSpec.describe RubySMB::SMB2::Client do
  subject(:client) do
    described_class.new(dispatcher: dispatcher, username: username, password: password)
  end

  let(:username) { 'administrator' }
  let(:password) { 'P@ssword1' }

  let!(:dispatcher) do
    MockSocketDispatcher.new
  end

  context 'with_negotiation' do
    before do
      expect(dispatcher).to receive(:send_packet).with(kind_of RubySMB::SMB2::Packet::Generic)
      expect(dispatcher).to receive(:recv_packet).and_return(negotiate_response)
    end

    let(:negotiate_response) { RubySMB::SMB2::Packet::NegotiateResponse.new }

    describe '#negotiate' do
      it 'runs without error' do
        expect{ client.negotiate }.not_to raise_error
      end

      it 'sets the sequence number' do
        expect{ client.negotiate }.to change{client.sequence_number}.to(0)
      end

      it 'sets the client capabailities' do
        expect{ client.negotiate }.to change{client.capabilities}.to(negotiate_response.capabilities)
      end

      it 'sets the state to negotiated' do
        expect{ client.negotiate }.to change{client.state}.to(:negotiated)
      end

    end

    describe '#authenticate' do
      before do
        expect{ client.negotiate }.not_to raise_error
        expect(client).to receive(:ntlmssp_negotiate).and_return(challenge)
        expect(client).to receive(:ntlmssp_auth).with(challenge).and_return(response)
      end

      let(:challenge) { RubySMB::SMB2::Packet::SessionSetupResponse.new }
      let(:response)  { RubySMB::SMB2::Packet::SessionSetupResponse.new }

      context 'with valid credentials' do
        before do
          response.nt_status = 0
        end

        it 'returns WindowsError::NTStatus::STATUS_SUCCESS' do
          expect(client.authenticate).to eq WindowsError::NTStatus::STATUS_SUCCESS
        end

        it 'sets state to authenticated' do
          expect{ client.authenticate }.to change{client.state}.to(:authenticated)
        end
      end

      context 'with invalid credentials' do
        before do
          response.nt_status = 0xC000006D
        end

        it 'returns WindowsError::NTStatus::STATUS_LOGON_FAILURE' do
          expect(client.authenticate).to eq WindowsError::NTStatus::STATUS_LOGON_FAILURE
        end

        it 'sets state to authentication_failed' do
          expect{ client.authenticate }.to change{client.state}.to(:authentication_failed)
        end
      end
    end

    describe '#ntlmssp_negotiate' do
      before do
        expect{ client.negotiate }.not_to raise_error
        expect(dispatcher).to receive(:send_packet).with(kind_of RubySMB::SMB2::Packet::SessionSetupRequest)
        expect(dispatcher).to receive(:recv_packet).and_return(RubySMB::SMB2::Packet::SessionSetupResponse.new)
      end

      it 'runs without error' do
        expect{ client.ntlmssp_negotiate }.not_to raise_error
      end
    end
  end


end
