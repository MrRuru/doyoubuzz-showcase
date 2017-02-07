require 'spec_helper'

require 'doyoubuzz/showcase'

describe Doyoubuzz::Showcase do
  let(:api_key) { 'an_api_key' }
  let(:api_secret) { 'an_api_secret' }
  let(:showcase) { Doyoubuzz::Showcase.new(api_key, api_secret) }

  describe '#new' do
    it 'requires an api key and secret key' do
      expect { Doyoubuzz::Showcase.new }.to raise_error ArgumentError

      expect { Doyoubuzz::Showcase.new(api_key, api_secret) }.to_not raise_error
    end
  end

  describe '#call' do
    let(:arguments) { { foo: 'bar', zab: 'baz' } }
    let(:timestamp) { 1370534334 }

    # The timestamp is important in the request generation and the VCR
    # handling. Here it is set at a fixed date
    before do
      time = Time.at(timestamp)
      allow(Time).to receive(:now).and_return time
    end

    it 'generates a valid signed api call' do
      # We only want to check the sent parameters here
      allow(showcase).to receive(:process_response)
      expect(showcase.class).to receive(:get).with(
        '/path',
        query: {
          foo: 'bar',
          zab: 'baz',
          apikey: 'an_api_key',
          timestamp: timestamp,
          hash: '757b04a866f1d02f077471589341ff7a'
        }
      )

      showcase.get('/path', arguments)
    end

    it 'puts the parameters in the body for PUT requests' do
      # We only want to check the sent parameters here
      allow(showcase).to receive(:process_response)
      expect(showcase.class).to receive(:put).with(
        '/path',
        query: {
          apikey: 'an_api_key',
          timestamp: timestamp,
          hash: '11a68a1bb9e23c681438efb714c9ad4d'
        },
        body: { foo: 'bar', zab: 'baz' }
      )

      showcase.put('/path', arguments)
    end

    it 'handles HTTP verbs' do
      expect(showcase).to respond_to(:get)
      expect(showcase).to respond_to(:post)
      expect(showcase).to respond_to(:put)
      expect(showcase).to respond_to(:delete)
    end

    it 'returns an explorable hash' do
      VCR.use_cassette('good_call') do
        res = showcase.get('/users')

        expect(res.keys).to eq(%w(users total next))
        expect(res['users']['items'].first.keys).
          to eq(%w(username email firstname lastname id))
        expect(res.users.items.first.username).
          to eq('lvrmterjwea')
      end
    end

    it 'handles array responses' do
      VCR.use_cassette('good_call') do
        res = showcase.get('/tags')

        expect(res).to be_an(Array)
        expect(res.first).to be_a(Hashie::Mash)
      end
    end

    it 'raises an exception on a failed call' do
      VCR.use_cassette('failed_call') do
        expect { showcase.get('/users') }.to raise_error do |error|
          expect(error).to be_a(Doyoubuzz::Showcase::Error)
          expect(error.status).to eq(403)
          expect(error.message).to eq('Forbidden')
        end
      end
    end
  end

  describe '#sso_redirect_url' do
    let(:company_name) { 'my_company' }
    let(:timestamp) { 1370534334 }
    let(:user_attributes) do
      {
        email: 'email@host.tld',
        firstname: 'John',
        lastname: 'Doe',
        external_id: 12345
      }
    end
    let(:sso_key) { 'vpsdihgfdso' }

    it 'verifies all the mandatory user attributes are given' do
      user_attributes.keys.each do |mandatory_key|
        incomplete_attributes = user_attributes.reject { |k, _| k == mandatory_key }

        expect do
          showcase.sso_redirect_url(
            company_name,
            timestamp,
            sso_key,
            incomplete_attributes
          )
        end.to raise_error(
          ArgumentError,
          "Missing mandatory attributes for SSO : #{mandatory_key}"
        )
      end
    end

    it 'computes the right url' do
      expect(
        showcase.sso_redirect_url(
          company_name,
          timestamp,
          sso_key,
          user_attributes
        )
      ).to eq('http://showcase.doyoubuzz.com/p/fr/my_company/sso?email=email%40host.tld&firstname=John&lastname=Doe&external_id=12345&timestamp=1370534334&hash=94a0adad0a9bafdf511326cae3bf7626')
    end
  end
end
