require 'spec_helper'

describe ActiveFedora::FixityService do
  let(:service) { described_class.new(uri) }
  let(:uri) { RDF::URI("http://path/to/resource") }

  describe "the instance" do
    subject { described_class.new(uri) }
    it { is_expected.to respond_to(:response) }
  end

  describe "initialize" do
    context "with a string" do
      subject { service.target }
      let(:uri) { 'http://path/to/resource' }
      it { is_expected.to eq 'http://path/to/resource' }
    end

    context "with an RDF::URI" do
      subject { service.target }
      it { is_expected.to eq 'http://path/to/resource' }
    end
  end

  describe "#check" do
    before { allow(service).to receive(:fixity_response_from_fedora).and_return(response) }
    subject { service.check }

    context "with Fedora version >= 4.4.0" do
      context "with a passing result" do
        let(:response) do
          instance_double("Response", body: '<subject> <http://www.loc.gov/premis/rdf/v1#hasEventOutcome> "SUCCESS"^^<http://www.w3.org/2001/XMLSchema#string> .')
        end
        it { is_expected.to be true }
      end

      context "with a failing result" do
        let(:response) do
          instance_double("Response", body: '<subject> <http://www.loc.gov/premis/rdf/v1#hasEventOutcome> "BAD_CHECKSUM"^^<http://www.w3.org/2001/XMLSchema#string> .')
        end
        it { is_expected.to be false }
      end
    end

    context "with Fedora version < 4.4.0" do
      context "with a passing result" do
        let(:response) do
          instance_double("Response", body: '<subject> <http://fedora.info/definitions/v4/repository#status> "SUCCESS"^^<http://www.w3.org/2001/XMLSchema#string> .')
        end
        it { is_expected.to be true }
      end

      context "with a failing result" do
        let(:response) do
          instance_double("Response", body: '<subject> <http://fedora.info/definitions/v4/repository#status> "BAD_CHECKSUM"^^<http://www.w3.org/2001/XMLSchema#string> .')
        end
        it { is_expected.to be false }
      end
    end

    context "with a non-existent predicate" do
      let(:response) do
        instance_double("Response", body: '<subject> <http://bogus.com/definitions/v1/bogusTerm#foo> "SUCCESS"^^<http://www.w3.org/2001/XMLSchema#string> .')
      end
      it { is_expected.to be false }
    end
  end
end
