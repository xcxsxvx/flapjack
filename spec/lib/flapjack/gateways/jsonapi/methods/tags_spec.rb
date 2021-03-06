require 'spec_helper'
require 'flapjack/gateways/jsonapi'

describe 'Flapjack::Gateways::JSONAPI::Methods::Tags', :sinatra => true, :logger => true, :pact_fixture => true do

  include_context "jsonapi"

  let(:tag)   { double(Flapjack::Data::Tag, :id => tag_data[:name]) }
  let(:tag_2) { double(Flapjack::Data::Tag, :id => tag_2_data[:name]) }

  let(:tag_data_with_id)   { tag_data.merge(:id => tag_data[:name]) }
  let(:tag_2_data_with_id) { tag_2_data.merge(:id => tag_2_data[:name]) }

  let(:check) { double(Flapjack::Data::Check, :id => check_data[:id]) }
  let(:rule)  { double(Flapjack::Data::Rule, :id => rule_data[:id]) }

  it "creates a tag" do
    expect(Flapjack::Data::Tag).to receive(:lock).
      with(Flapjack::Data::Check, Flapjack::Data::Rule, Flapjack::Data::Route).
      and_yield

    empty_ids = double('empty_ids')
    expect(empty_ids).to receive(:ids).and_return([])
    expect(Flapjack::Data::Tag).to receive(:intersect).
      with(:name => [tag_data[:name]]).and_return(empty_ids)

    expect(tag).to receive(:invalid?).and_return(false)
    expect(tag).to receive(:save).and_return(true)
    expect(Flapjack::Data::Tag).to receive(:new).with(tag_data_with_id).
      and_return(tag)

    expect(tag).to receive(:as_json).with(:only => an_instance_of(Array)).
      and_return(tag_data_with_id)

    expect(Flapjack::Data::Tag).to receive(:jsonapi_type).and_return('tag')

    post "/tags", Flapjack.dump_json(:data => tag_data.merge(:type => 'tag')), jsonapi_env
    expect(last_response.status).to eq(201)
    expect(last_response.body).to be_json_eql(Flapjack.dump_json(:data =>
      tag_data_with_id.merge(
        :type => 'tag',
        :links => {:self  => "http://example.org/tags/#{tag.id}",
                   :checks => "http://example.org/tags/#{tag.id}/checks",
                   :rules => "http://example.org/tags/#{tag.id}/rules"})
    ))
  end

  it "retrieves paginated tags" do
    meta = {
      :pagination => {
        :page        => 1,
        :per_page    => 20,
        :total_pages => 1,
        :total_count => 1
      }
    }

    links = {
      :self  => 'http://example.org/tags',
      :first => 'http://example.org/tags?page=1',
      :last  => 'http://example.org/tags?page=1'
    }

    page = double('page', :all => [tag])
    sorted = double('sorted')
    expect(sorted).to receive(:page).with(1, :per_page => 20).
      and_return(page)
    expect(sorted).to receive(:count).and_return(1)
    expect(Flapjack::Data::Tag).to receive(:sort).with(:id).and_return(sorted)

    expect(tag).to receive(:as_json).with(:only => an_instance_of(Array)).
      and_return(tag_data)

    get '/tags'
    expect(last_response).to be_ok
    expect(last_response.body).to be_json_eql(Flapjack.dump_json(:data => [
      tag_data_with_id.merge(
        :type => 'tag',
        :links => {:self  => "http://example.org/tags/#{tag.id}",
                   :checks => "http://example.org/tags/#{tag.id}/checks",
                   :rules => "http://example.org/tags/#{tag.id}/rules"})],
    :links => links, :meta => meta))
  end

  it "retrieves paginated tags matching a filter" do
    meta = {
      :pagination => {
        :page        => 1,
        :per_page    => 20,
        :total_pages => 1,
        :total_count => 1
      }
    }

    links = {
      :self  => 'http://example.org/tags?filter%5B%5D=name%3Adatabase',
      :first => 'http://example.org/tags?filter%5B%5D=name%3Adatabase&page=1',
      :last  => 'http://example.org/tags?filter%5B%5D=name%3Adatabase&page=1'
    }

    filtered = double('filtered')
    expect(Flapjack::Data::Tag).to receive(:intersect).with(:name => Regexp.new('database')).
      and_return(filtered)

    page = double('page', :all => [tag])
    sorted = double('sorted')
    expect(sorted).to receive(:page).with(1, :per_page => 20).and_return(page)
    expect(sorted).to receive(:count).and_return(1)
    expect(filtered).to receive(:sort).with(:id).and_return(sorted)

    expect(tag).to receive(:as_json).with(:only => an_instance_of(Array)).
      and_return(tag_data)

    expect(Flapjack::Data::Tag).to receive(:jsonapi_type).and_return('tag')

    get '/tags?filter%5B%5D=name%3Adatabase'
    expect(last_response).to be_ok
    expect(last_response.body).to be_json_eql(Flapjack.dump_json(:data => [
      tag_data.merge(
        :type => 'tag',
        :links => {:self   => "http://example.org/tags/#{tag.id}",
                   :checks => "http://example.org/tags/#{tag.id}/checks",
                   :rules  => "http://example.org/tags/#{tag.id}/rules"})],
      :links => links, :meta => meta))
  end

  it "retrieves one tag" do
    expect(Flapjack::Data::Tag).to receive(:find_by_id!).
      with(tag.id).and_return(tag)

    expect(tag).to receive(:as_json).with(:only => an_instance_of(Array)).
      and_return(tag_data)

    get "/tags/#{tag.id}"
    expect(last_response).to be_ok
    expect(last_response.body).to be_json_eql(Flapjack.dump_json(:data =>
      tag_data_with_id.merge(
        :type => 'tag',
        :links => {:self  => "http://example.org/tags/#{tag.id}",
                   :checks => "http://example.org/tags/#{tag.id}/checks",
                   :rules => "http://example.org/tags/#{tag.id}/rules"}),
    :links => {:self  => "http://example.org/tags/#{tag.id}"}))
  end

  it "retrieves several tags" # do
  #   sorted = double('sorted')
  #   expect(sorted).to receive(:find_by_ids!).
  #     with(tag.id, tag_2.id).and_return([tag, tag_2])
  #   expect(Flapjack::Data::Tag).to receive(:sort).with(:id).and_return(sorted)

  #   expect(tag).to receive(:as_json).with(:only => an_instance_of(Array)).
  #     and_return(tag_data)

  #   expect(tag_2).to receive(:as_json).with(:only => an_instance_of(Array)).
  #     and_return(tag_2_data)

  #   get "/tags/#{tag.id},#{tag_2.id}"
  #   expect(last_response).to be_ok

  #   expect(last_response.body).to be_json_eql(Flapjack.dump_json(:data => [
  #     tag_data_with_id.merge(
  #       :type => 'tag',
  #       :links => {:self  => "http://example.org/tags/#{tag.id}",
  #                  :checks => "http://example.org/tags/#{tag.id}/checks",
  #                  :rules => "http://example.org/tags/#{tag.id}/rules"}),
  #     tag_2_data_with_id.merge(
  #       :type => 'tag',
  #       :links => {:self  => "http://example.org/tags/#{tag_2.id}",
  #                  :checks => "http://example.org/tags/#{tag_2.id}/checks",
  #                  :rules => "http://example.org/tags/#{tag_2.id}/rules"})],
  #   :links => {:self  => "http://example.org/tags/#{tag.id},#{tag_2.id}"}))
  # end

  it 'sets a linked check for a tag' do
    expect(Flapjack::Data::Check).to receive(:find_by_ids!).
      with(check.id).and_return([check])

    expect(tag).to receive(:invalid?).and_return(false)
    expect(tag).to receive(:save).and_return(true)

    checks = double('checks', :ids => [])
    expect(checks).to receive(:add).with(check)
    expect(tag).to receive(:checks).twice.and_return(checks)

    expect(Flapjack::Data::Tag).to receive(:find_by_id!).with(tag.id).and_return(tag)

    expect(Flapjack::Data::Tag).to receive(:jsonapi_type).and_return('tag')

    patch "/tags/#{tag.id}",
      Flapjack.dump_json(:data => {:id => tag.id, :type => 'tag', :links =>
        {:checks => {:linkage => [{:type => 'check', :id => check.id}]}}}),
      jsonapi_env
    expect(last_response.status).to eq(204)
  end

  it "deletes a tag" do
    expect(tag).to receive(:destroy)
    expect(Flapjack::Data::Tag).to receive(:find_by_id!).
      with(tag.id).and_return(tag)

    delete "/tags/#{tag.id}"
    expect(last_response.status).to eq(204)
  end

  it "deletes multiple tags" do
    tags = double('tags')
    expect(tags).to receive(:count).and_return(2)
    expect(tags).to receive(:destroy_all)
    expect(Flapjack::Data::Tag).to receive(:intersect).
      with(:id => [tag.id, tag_2.id]).and_return(tags)

    delete "/tags",
      Flapjack.dump_json(:data => [
        {:id => tag.id, :type => 'tag'},
        {:id => tag_2.id, :type => 'tag'}
      ]),
      jsonapi_bulk_env

    expect(last_response.status).to eq(204)
  end

  it "does not delete a tag that does not exist" do
    expect(Flapjack::Data::Tag).to receive(:find_by_id!).
      with(tag.id).and_raise(Zermelo::Records::Errors::RecordNotFound.new(Flapjack::Data::Tag, tag.id))

    delete "/tags/#{tag.id}"
    expect(last_response).to be_not_found
  end

end
