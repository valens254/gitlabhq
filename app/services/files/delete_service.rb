module Files
  class DeleteService < Files::BaseService
    def commit
      repository.remove_file(
        current_user,
        @file_path,
        @commit_message,
        @target_branch,
        author_email: @author_email,
        author_name: @author_name,
        source_branch: @source_branch)
    end
  end
end
