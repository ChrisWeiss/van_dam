require "rails_helper"

RSpec.describe "Creators" do
  before :all do
    create_list(:creator, 13) do |creator|
      create_list(:link, 1, linkable: creator)
      create_list(:model, 1, creator: creator)
    end
  end

  describe "GET /creators?page=2" do
    it "returns paginated creators" do
      get "/creators?page=2"
      expect(response).to have_http_status(:success)
      expect(response.body).to match(/pagination/)
    end
  end
end
