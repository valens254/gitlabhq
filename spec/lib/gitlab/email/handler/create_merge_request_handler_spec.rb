require 'spec_helper'
require_relative '../email_shared_blocks'

describe Gitlab::Email::Handler::CreateMergeRequestHandler do
  include_context :email_shared_context
  it_behaves_like :reply_processing_shared_examples

  before do
    stub_incoming_email_setting(enabled: true, address: "incoming+%{key}@appmail.adventuretime.ooo")
    stub_config_setting(host: 'localhost')
  end

  let(:email_raw) { fixture_file('emails/valid_new_merge_request.eml') }
  let(:namespace) { create(:namespace, path: 'gitlabhq') }

  # project's git repository is not deleted when project is deleted
  # between tests. Then tests fail because re-creation of the project with
  # the same name fails on existing git repository -> skip_disk_validation
  # ignores repository existence on disk
  let!(:project)  { create(:project, :public, :repository, skip_disk_validation: true, namespace: namespace, path: 'gitlabhq') }
  let!(:user) do
    create(
      :user,
      email: 'jake@adventuretime.ooo',
      incoming_email_token: 'auth_token'
    )
  end

  context "as a non-developer" do
    before do
      project.add_guest(user)
    end

    it "raises UserNotAuthorizedError if the user is not a member" do
      expect { receiver.execute }.to raise_error(Gitlab::Email::UserNotAuthorizedError)
    end
  end

  context "as a developer" do
    before do
      project.add_developer(user)
    end

    context "when everything is fine" do
      it "creates a new merge request" do
        expect { receiver.execute }.to change { project.merge_requests.count }.by(1)
        merge_request = project.merge_requests.last

        expect(merge_request.author).to eq(user)
        expect(merge_request.source_branch).to eq('feature')
        expect(merge_request.title).to eq('Feature added')
        expect(merge_request.target_branch).to eq(project.default_branch)
      end
    end

    context "something is wrong" do
      context "when the merge request could not be saved" do
        before do
          allow_any_instance_of(MergeRequest).to receive(:save).and_return(false)
        end

        it "raises an InvalidMergeRequestError" do
          expect { receiver.execute }.to raise_error(Gitlab::Email::InvalidMergeRequestError)
        end
      end

      context "when we can't find the incoming_email_token" do
        let(:email_raw) { fixture_file("emails/wrong_incoming_email_token.eml") }

        it "raises an UserNotFoundError" do
          expect { receiver.execute }.to raise_error(Gitlab::Email::UserNotFoundError)
        end
      end

      context "when the subject is blank" do
        let(:email_raw) { fixture_file("emails/valid_new_merge_request_no_subject.eml") }

        it "raises an InvalidMergeRequestError" do
          expect { receiver.execute }.to raise_error(Gitlab::Email::InvalidMergeRequestError)
        end
      end
    end
  end
end
