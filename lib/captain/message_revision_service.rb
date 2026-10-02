class Captain::MessageRevisionService
  pattr_initialize [:account!, :user!, :content!, :conversation_display_id!, :request_id!]

  def perform
    conversation = account.conversations.find_by!(display_id: conversation_display_id)
    revision = Captain::MessageRevision.create!(account: account, conversation: conversation, user: user,
                                                request_id: request_id, original_content: content)
    service = Captain::RewriteService.new(account: account, content: content, operation: 'auto_fix_grammar',
                                          conversation_display_id: conversation_display_id)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = perform_revision(service)
    details = service.grammar_revision_details || { outcome: 'error', reason: 'revision_unavailable' }
    details = { outcome: 'error', error_class: @error_class, reason: 'revision_error' } if @error_class
    revision.update!(**details, selected_content: result[:message] || content, duration_ms: elapsed_ms(started))
    { message: result[:message] || content, revision_id: revision.id }
  end

  private

  def perform_revision(service)
    service.perform
  rescue StandardError => e
    @error_class = e.class.name
    { message: content }
  end

  def elapsed_ms(started)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
  end
end
