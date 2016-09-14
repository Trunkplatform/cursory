require 'spec_helper'
require 'base64'
require 'cursory/mongoid'

module Cursory
  describe Mongoid do
    def encode_json(data)
      ::Base64.urlsafe_encode64(JSON.dump(data))
    end

    let(:criteria) { double(klass: model) }
    let(:id)       { 'outrageous-offset' }
    let(:result)   { double(id: id) }
    let(:model)    { double }
    let(:params)   { {} }
    let(:results)  { [] }

    subject { described_class.new(criteria, params) }

    before do
      allow(model).to    receive(:find).with(id).and_return(result)
      allow(criteria).to receive(:order_by).and_return(criteria)
      allow(criteria).to receive(:limit).and_return(criteria)
      allow(criteria).to receive(:where).and_return(criteria)
      allow(criteria).to receive(:skip).and_return(criteria)
      allow(criteria).to receive(:to_a).and_return(results)
      allow(criteria).to receive(:count)
    end

    context "with and invalid cursor parameter" do
      let(:params)  { { cursor: '' } }

      it "raises an exception for an invalid cursor" do
        expect { expect(subject.page) }.to raise_error(InvalidCursorError)
      end
    end

    context "in normal operation" do
      after do
        subject.page
      end

      describe 'sorting' do
        it "orders by key by default" do
          expect(criteria).to receive(:order_by).with(:id=>"asc")
        end

        context "with a single sort parameter" do
          let(:params) { {sort: 'name'} }

          it "orders by key, and by _id" do
            expect(criteria).to receive(:order_by).with(name: 'asc', id: "asc")
          end
        end

        context "with multiple sort parameters (including reversal)" do
          let(:params) { {sort: 'name,-created_at'} }

          it "orders by all keys, and by _id" do
            expect(criteria).to receive(:order_by).with(name: 'asc', created_at: 'desc', id: "asc")
          end
        end
      end

      describe 'cursors' do
        context "with no sort info" do
          it "doesn't bother with a 'where' clause by default" do
            expect(criteria).not_to receive(:where)
          end

          it "doesn't provide a 'next' cursor for less than 'limit' results" do
            expect(subject.page[:next]).to be nil
          end

          context "with 1 result" do
            let(:results) { double }

            before do
              allow(results).to receive(:[]).with(9).and_return(result)
            end

            it "provides a 'next' cursor for 'limit' or more results" do
              expect(subject.page[:next]).to eq encode_json({id: id})
            end

            context "on a request for the 'next' results" do
              let(:params) { { cursor: encode_json(id: id) } }
              it "specifies a basic 'where' clause for the second page" do
                expect(criteria).to receive(:where).with( "$or" => [ {:id => {"$gt"=>"outrageous-offset"}} ] )
              end
            end
          end
        end

        context "with sort info" do
          let(:params) { {sort: 'name'} }

          it "doesn't bother with a 'where' clause by default" do
            expect(criteria).not_to receive(:where)
          end

          context 'with a cursor' do
            let(:result) { double('result', id: id, name: name, age: age, created_at: created_at) }
            let(:params) { { sort: 'name', cursor: encode_json(id: id) } }
            let(:created_at) { Time.now }
            let(:name) { 'Simon' }
            let(:age) { 37 }

            before do
              allow(model).to receive(:find).with(id).and_return(result)
            end

            it "specifies a 'where' clause with a cursor" do
              expect(criteria).to receive(:where).with( '$or' => [
                { name: { '$gt' => name } },
                { name: { '$eq' => name }, id: { '$gt' => id } }
              ])
            end

            context 'with multiple sort params' do
              let(:params) { { sort: 'name,-age,-created_at', cursor: encode_json(id: id) } }

              before do
                allow(results).to receive(:[]).with(9).and_return(result)
              end

              it "specifies a 'where' clause with a cursor" do
                expect(criteria).to receive(:where).with( '$or' => [
                  { name: { '$gt' => name } },
                  { name: { '$eq' => name }, age: { '$lt' => age } },
                  { name: { '$eq' => name }, age: { '$eq' => age }, created_at: { '$lt' => created_at } },
                  { name: { '$eq' => name }, age: { '$eq' => age }, created_at: { '$eq' => created_at }, id: { '$gt' => id } }
                ])
              end
            end
          end
        end
      end
    end
  end
end
