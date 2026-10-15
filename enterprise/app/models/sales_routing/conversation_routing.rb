module SalesRouting::ConversationRouting
  extend ActiveSupport::Concern

  included do
    before_validation :sync_store_from_team_change, if: -> { team_id_changed? && !Current.executed_by.is_a?(AssignmentPolicy) }
  end

  private

  def sync_store_from_team_change
    configuration = SalesRouting::Configuration.new(inbox: inbox)
    route = additional_attributes[SalesRouting::Classifier::ATTRIBUTES_KEY]
    return unless configuration.enabled? && route.present?

    code = configuration.store_for_team(team_id)
    return unless code && code != route['store']

    label_list.remove(*configuration.stores.values.map { |store| store.fetch('label') }, 'loja-indefinida')
    label_list.add(configuration.stores.fetch(code).fetch('label'))
    additional_attributes[SalesRouting::Classifier::ATTRIBUTES_KEY] = SalesRouting::Classifier.with_origin_store(route).merge(
      'store' => code, 'rule' => 'manual-team', 'assignment_rule' => 'manual-team', 'preferred_agent_id' => nil
    )
  end
end
