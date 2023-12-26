# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Union SQL Queries" do
  let(:user)       { User.where(id: 1) }
  let(:other_user) { User.where("id = 2") }

  shared_examples_for "unions" do
    it { is_expected.to eq("#{user.to_sql} #{described_union} #{other_user.to_sql}") }
  end

  shared_examples_for "piping nest CTE tables" do
    let(:cte_user)      { User.with(all_others: User.where.not(id: 1)).where(id: 2) }
    let(:method)        { raise "Required to override this method!" }
    let(:single_with)   { /^WITH .all_others. AS(?!.*WITH \w?)/mi }
    let(:override_with) { /^WITH .all_others. AS \(.+WHERE .users.\..id. = 10\)/mi }

    it "pushes the CTE to the callee's level" do
      query = User.send(method.to_sym, cte_user, other_user).to_sql
      expect(query).to match_regex(single_with)
    end

    it "favors the parents CTE table if names collide" do
      query = User.with(all_others: User.where(id: 10))
      query = query.send(method.to_sym, cte_user, other_user).to_sql

      expect(query).to match_regex(single_with)
      expect(query).to match_regex(override_with)
    end
  end

  describe ".union" do
    subject(:described_method) { User.union(user, other_user).to_union_sql }

    let(:described_union) { "UNION" }

    it_behaves_like "unions"
    it_behaves_like "piping nest CTE tables" do
      let(:method) { :union }
    end
  end

  describe ".union.all" do
    subject(:described_method) { User.union.all(user, other_user).to_union_sql }

    let(:described_union) { "UNION ALL" }

    it_behaves_like "unions"
    it_behaves_like "piping nest CTE tables" do
      let(:method) { :union_all }
    end
  end

  describe ".union.except" do
    subject(:described_method) { User.union.except(user, other_user).to_union_sql }

    let(:described_union) { "EXCEPT" }

    it_behaves_like "unions"
    it_behaves_like "piping nest CTE tables" do
      let(:method) { :union_except }
    end
  end

  describe "union.intersect" do
    subject(:described_method) { User.union.intersect(user, other_user).to_union_sql }

    let(:described_union) { "INTERSECT" }

    it_behaves_like "unions"
    it_behaves_like "piping nest CTE tables" do
      let(:method) { :union_intersect }
    end
  end

  describe "union.as" do
    context "when a union.as has been called" do
      subject(:described_method) do
        User.select("happy_users.id").union(user, other_user).union.as(:happy_users).to_sql
      end

      it "aliases the union from clause to 'happy_users'" do
        expect(described_method).to match_regex(/FROM .+ UNION .+ happy_users$/)
        expect(described_method).to match_regex(/^SELECT (happy_users\.id|"happy_users"\."id") FROM.+happy_users$/)
      end
    end

    context "when user.as hasn't been called" do
      subject(:described_method) { User.select(:id).union(user, other_user).to_sql }

      it "retains the actual class calling table name as the union alias" do
        expect(described_method).to match_regex(/FROM .+ UNION .+ users$/)
        expect(described_method).to match_regex(/^SELECT "users"\."id" FROM.+users$/)
      end
    end
  end

  describe "union.order" do
    context "when rendering with .to_union_sql" do
      subject(:described_method) { User.union(user, other_user).union.order(:id, name: :desc).to_union_sql }

      it "appends an 'ORDER BY' to the end of the union statements" do
        expect(described_method).to match_regex(/^.+ UNION .+\) ORDER BY id, name DESC$/)
      end
    end

    context "when rendering with .to_sql" do
      subject(:described_method) { User.union(user, other_user).union.order(:id, name: :desc).to_sql }

      it "appends an 'ORDER BY' to the end of the union statements" do
        expect(described_method).to match_regex(/FROM .+ UNION .+\) ORDER BY id, name DESC\) users$/)
      end
    end

    context "when a there are multiple union statements" do
      let(:query_regex) { /(?<=\)\s(ORDER BY)) id/ }

      it "onlies append an order by to the very end of a union statements" do
        query = User.union.order(id: :asc, tags: :desc)
                    .union(user.order(id: :asc, tags: :desc))
                    .union(user.order(:id, :tags))
                    .union(other_user.order(id: :desc, tags: :desc))
                    .to_union_sql

        index = query.index(query_regex)
        expect(index).to be_truthy
        expect(query[index..-1]).to eq(" id ASC, tags DESC")
      end
    end
  end
end
