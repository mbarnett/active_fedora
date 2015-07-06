require 'spec_helper'
@@last_id = 0

describe ActiveFedora::Base do
  describe "descendant_uris" do

    before :each do
      ids.each do |id|
        ActiveFedora::Base.create id: id
      end
    end

    def root_uri(ids=[])
      ActiveFedora::Base.id_to_uri(ids.first)
    end

    context 'when there there are no descendants' do

      let(:ids) { ['foo'] }

      it 'returns an array containing only the URI passed to it' do
        expect(ActiveFedora::Base.descendant_uris(root_uri(ids))).to eq ids.map {|id| ActiveFedora::Base.id_to_uri(id) }
      end
    end

    context 'when there are > 1 descendants' do

      let(:ids) { ['foo', 'foo/bar', 'foo/bar/chu'] }

      it 'returns an array containing the URI passed to it, as well as all descendant URIs' do
        expect(ActiveFedora::Base.descendant_uris(root_uri(ids))).to eq ids.map {|id| ActiveFedora::Base.id_to_uri(id) }
      end
    end

    context 'when some of the decendants are not RDFSources' do
      let(:ids) { ['foo', 'foo/bar'] }
      let(:datastream) { ActiveFedora::Datastream.new(ActiveFedora::Base.id_to_uri('foo/bar/bax')) }

      before do
        datastream.content = "Hello!!!"
        datastream.save
      end

      it "should not put the datastream in the decendants list" do
        expect(ActiveFedora::Base.descendant_uris(root_uri(ids))).not_to include datastream.uri
      end
    end

    describe "reindex_everything" do
      let(:ids) { ['foo', 'bar'] }
      let(:solr) { ActiveFedora::SolrService.instance.conn }
      before do
        solr.delete_by_query('*:*', params: {'softCommit' => true})
      end
      it "should call update_index on every object represented in the sitemap" do
        expect {
          ActiveFedora::Base.reindex_everything
        }.to change { ActiveFedora::SolrService.query('id:foo').size }.from(0).to(1)
      end
    end
  end

  describe "with an autosave association, where some records are deleted" do
    before do
      class GenericFile < ActiveFedora::Base
        has_many :permissions, predicate: ::RDF::Vocab::ACL.accessTo
        accepts_nested_attributes_for :permissions, allow_destroy: true
        property :title, predicate: ::RDF::DC.title

        def to_solr
          super.tap do |doc|
            doc['permissions_ssim'] = permission_ids
          end
        end
      end

      class Permission < ActiveFedora::Base
        belongs_to :generic_file, predicate: ::RDF::Vocab::ACL.accessTo
      end
    end

    let(:p1) { Permission.create! }
    let(:p2) { Permission.create! }
    let(:gf) { GenericFile.create(permissions: [p1, p2]) }

    before { gf.update(permissions_attributes: [{ id: p1.id, _destroy: 'true' }]) }

    it "saves to solr correctly" do
      result = ActiveFedora::SolrService.query("id:#{gf.id}").first['permissions_ssim']
      expect(result).to eq [p2.id]
    end
  end
end
