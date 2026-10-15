class Enterprise::Api::V2::Accounts::AgentResponseReportsController < Api::V1::Accounts::BaseController
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100
  MAX_PAGE = 10_000

  before_action :check_authorization
  rescue_from V2::AgentResponseReports::Filters::Invalid, with: :render_invalid_filters

  def summary
    render json: V2::AgentResponseReports::SummaryBuilder.new(filters: filters).build
  end

  def details
    kind = params[:kind]
    metric = details_metric(kind)
    builder = V2::AgentResponseReports::DetailsBuilder.new(filters: filters, kind: kind, metric: metric, sample: attempts_sample(kind, metric),
                                                           page: page_param(:page, 1, MAX_PAGE),
                                                           per_page: page_param(:per_page, DEFAULT_PER_PAGE, MAX_PER_PAGE))
    render json: builder.build
  end

  private

  def check_authorization
    authorize :report, :view?
  end

  # Filters read the raw params so malformed shapes fail validation instead of being dropped by strong params.
  def filters
    V2::AgentResponseReports::Filters.new(account: Current.account, params: params)
  end

  def details_metric(kind)
    case kind
    when 'attempts'
      return if params[:outcome].nil?
      return params[:outcome] if V2::AgentResponseReports::DetailsBuilder::ATTEMPT_OUTCOMES.include?(params[:outcome])
    when 'conversations'
      return params[:metric] if V2::AgentResponseReports::DetailsBuilder::CONVERSATION_METRICS.include?(params[:metric])
    end

    raise V2::AgentResponseReports::Filters::Invalid, I18n.t('errors.agent_response_reports.invalid_detail')
  end

  def attempts_sample(kind, outcome)
    return if params[:sample].nil?
    return params[:sample] if kind == 'attempts' && outcome.nil? && V2::AgentResponseReports::DetailsBuilder::ATTEMPT_SAMPLES.key?(params[:sample])

    raise V2::AgentResponseReports::Filters::Invalid, I18n.t('errors.agent_response_reports.invalid_detail')
  end

  def page_param(name, default, max)
    value = params.fetch(name, default.to_s)
    valid = value.is_a?(String) && value.match?(V2::AgentResponseReports::Filters::ID_FORMAT) && value.to_i <= max
    raise V2::AgentResponseReports::Filters::Invalid, I18n.t('errors.agent_response_reports.invalid_page', field: name, max: max) unless valid

    value.to_i
  end

  def render_invalid_filters(error)
    render_could_not_create_error(error.message)
  end
end
