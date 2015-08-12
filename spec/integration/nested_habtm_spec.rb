require 'spec_helper'

describe "Nested HABTM relationships" do

  before do
    class Work < ActiveFedora::Base
      has_and_belongs_to_many :assets, predicate: ActiveFedora::RDF::Fcrepo::RelsExt.hasMember, class_name: "Asset", inverse_of: :works
      accepts_nested_attributes_for :assets, allow_destroy: true
    end

    class Asset < ActiveFedora::Base
      has_many :works, inverse_of: :assets, class_name: "Work"
    end
  end

  after do
    Object.send(:remove_const, :Work)
    Object.send(:remove_const, :Asset)
  end


  describe "removing members" do

    let(:work)   { Work.create }
    let(:asset1) { Asset.create }
    let(:asset2) { Asset.create }

    context "when using .assets" do
      before do
        work.assets = [asset1, asset2]
        work.save
      end
      it "updates the membership of the work" do
        expect(work.assets.count).to eql 2
        asset1.destroy
        expect(work.assets.count).to eql 1
      end
    end

    # This scenario fails
    context "when using .asset_ids" do      
      before do
        work.asset_ids = [asset1.id, asset2.id]
        work.save
      end
      it "updates the membership of the work" do
        expect(work.assets.count).to eql 2
        asset1.destroy
        expect(work.assets.count).to eql 1
      end
    end

  end

end
