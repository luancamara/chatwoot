class Api::V1::Accounts::Captain::TasksController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def rewrite
    return render_result(automatic_revision) if params[:operation] == 'auto_fix_grammar'

    result = Captain::RewriteService.new(
      account: Current.account,
      content: params[:content],
      operation: params[:operation],
      conversation_display_id: params[:conversation_display_id]
    ).perform

    render_result(result)
  end

  def revisions
    conversation = Current.account.conversations.find_by!(display_id: params[:conversation_display_id])
    revisions = recent_revisions(conversation)
    messages = revision_messages(conversation, revisions.map { |r| r.id.to_s })
    render json: revisions.map { |revision| revision.as_json.merge(messages: messages.fetch(revision.id.to_s, [])) }
  end

  def summarize
    result = Captain::SummaryService.new(
      account: Current.account,
      conversation_display_id: params[:conversation_display_id]
    ).perform

    render_result(result)
  end

  def reply_suggestion
    result = Captain::ReplySuggestionService.new(
      account: Current.account,
      conversation_display_id: params[:conversation_display_id],
      user: Current.user
    ).perform

    render_result(result)
  end

  def label_suggestion
    result = Captain::LabelSuggestionService.new(
      account: Current.account,
      conversation_display_id: params[:conversation_display_id]
    ).perform

    render_result(result)
  end

  def follow_up
    result = Captain::FollowUpService.new(
      account: Current.account,
      follow_up_context: params[:follow_up_context]&.to_unsafe_h,
      user_message: params[:message],
      conversation_display_id: params[:conversation_display_id]
    ).perform

    render_result(result)
  end

  private

  def recent_revisions(conversation)
    revisions = Captain::MessageRevision.where(account: Current.account, conversation: conversation).order(id: :desc)
    revisions = revisions.where('id < ?', params[:before_id]) if params[:before_id].present?
    revisions.limit(50).to_a
  end

  def revision_messages(conversation, revision_ids)
    messages = conversation.messages.where("(content_attributes #>> '{}')::jsonb ->> 'grammar_revision_id' IN (?)", revision_ids)
    messages.group_by { |message| message.content_attributes['grammar_revision_id'].to_s }.transform_values do |group|
      group.map { |message| message.slice(:id, :content, :status, :source_id, :created_at) }
    end
  end

  def automatic_revision
    Captain::MessageRevisionService.new(account: Current.account, user: Current.user, content: params[:content],
                                        conversation_display_id: params[:conversation_display_id], request_id: request.request_id).perform
  end

  def render_result(result)
    if result.nil?
      render json: { message: nil }
    elsif result[:error]
      render json: { error: result[:error] }, status: :unprocessable_content
    else
      response_data = { message: result[:message] }
      response_data[:revision_id] = result[:revision_id] if result[:revision_id]
      response_data[:follow_up_context] = result[:follow_up_context] if result[:follow_up_context]
      render json: response_data
    end
  end

  def check_authorization
    authorize(:'captain/tasks')
  end
end

Api::V1::Accounts::Captain::TasksController.prepend_mod_with('Api::V1::Accounts::Captain::TasksController')
