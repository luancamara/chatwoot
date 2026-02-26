<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import CrmFilters from './components/CrmFilters.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const store = useStore();

const activeTab = ref('agents');
const allAgents = useMapGetter('agents/getAgents');
const managementData = useMapGetter(
  'crm/evaluationReports/getManagementEvaluation'
);
const uiFlags = useMapGetter('crm/evaluationReports/getUIFlags');
const expandedAgentId = ref(null);
const agentReport = useMapGetter('crm/evaluationReports/getAgentEvaluation');

const isLoading = computed(
  () => uiFlags.value.isFetchingManagement || uiFlags.value.isFetchingAgent
);

const management = computed(
  () => managementData.value?.data || managementData.value || {}
);
const ranking = computed(() => management.value?.ranking || []);
const aggregated = computed(() => management.value?.aggregated_metrics || {});
const worstConversations = computed(
  () => management.value?.worst_conversations || []
);
const bestConversations = computed(
  () => management.value?.best_conversations || []
);
const systemicIssues = computed(() => management.value?.systemic_issues || []);
const weeklyEvolution = computed(
  () => management.value?.weekly_evolution || []
);

const hasData = computed(
  () => ranking.value.length > 0 || Object.keys(aggregated.value).length > 0
);

const agentName = agentId => {
  const agent = allAgents.value.find(a => a.id === agentId);
  return agent?.name || `Agent #${agentId}`;
};

const trendIcon = trend => {
  if (trend === 'up') return 'i-lucide-trending-up';
  if (trend === 'down') return 'i-lucide-trending-down';
  return 'i-lucide-minus';
};

const trendColor = trend => {
  if (trend === 'up') return 'text-n-teal-11';
  if (trend === 'down') return 'text-n-ruby-11';
  return 'text-n-slate-11';
};

const scoreColor = score => {
  if (score == null) return 'text-n-slate-11';
  if (score >= 7) return 'text-n-teal-11';
  if (score >= 4) return 'text-n-amber-11';
  return 'text-n-ruby-11';
};

const formatMinutes = seconds => {
  if (seconds == null) return '--';
  const mins = Math.round(seconds / 60);
  if (mins < 60) return `${mins} min`;
  return `${(seconds / 3600).toFixed(1)} h`;
};

const criterionLabel = key => {
  return t(`CRM.CONVERSATION_INSIGHT.CRITERIA_LABELS.${key}`, key);
};

const toggleAgentDetail = agentId => {
  if (expandedAgentId.value === agentId) {
    expandedAgentId.value = null;
    return;
  }
  expandedAgentId.value = agentId;
  store.dispatch('crm/evaluationReports/fetchAgentEvaluation', {
    agentId,
    params: {},
  });
};

const onFilterChange = params => {
  store.dispatch('crm/evaluationReports/fetchManagementEvaluation', params);
};

onMounted(() => {
  store.dispatch('crm/evaluationReports/fetchManagementEvaluation', {});
});
</script>

<template>
  <div class="flex flex-col gap-6">
    <div>
      <h1 class="text-xl font-semibold text-n-slate-12">
        {{ t('CRM.EVALUATION_REPORTS.TITLE') }}
      </h1>
      <p class="mt-1 text-sm text-n-slate-11">
        {{ t('CRM.EVALUATION_REPORTS.DESCRIPTION') }}
      </p>
    </div>

    <CrmFilters @filter-change="onFilterChange" />

    <!-- Tabs -->
    <div class="flex gap-1 border-b border-n-weak">
      <button
        v-for="tab in ['agents', 'management', 'conversations']"
        :key="tab"
        class="px-4 py-2 text-sm font-medium transition-colors"
        :class="
          activeTab === tab
            ? 'text-n-blue-11 border-b-2 border-n-blue-9'
            : 'text-n-slate-11 hover:text-n-slate-12'
        "
        @click="activeTab = tab"
      >
        {{ t(`CRM.EVALUATION_REPORTS.TAB_${tab.toUpperCase()}`) }}
      </button>
    </div>

    <div v-if="isLoading" class="flex justify-center py-12">
      <Spinner />
    </div>

    <template v-else-if="hasData">
      <!-- TAB: Agents -->
      <div v-if="activeTab === 'agents'" class="flex flex-col gap-4">
        <div
          class="p-6 rounded-xl bg-n-solid-2 outline outline-1 outline-n-container"
        >
          <h2 class="mb-4 text-base font-semibold text-n-slate-12">
            {{ t('CRM.EVALUATION_REPORTS.AGENT_RANKING') }}
          </h2>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-n-weak">
                  <th class="py-2 text-left font-medium text-n-slate-11">
                    {{ t('CRM.FILTERS.AGENT') }}
                  </th>
                  <th class="py-2 text-right font-medium text-n-slate-11">
                    {{ t('CRM.EVALUATION_REPORTS.AVG_SCORE') }}
                  </th>
                  <th class="py-2 text-right font-medium text-n-slate-11">
                    {{ t('CRM.EVALUATION_REPORTS.TREND') }}
                  </th>
                  <th class="py-2 text-right font-medium text-n-slate-11">
                    {{ t('CRM.EVALUATION_REPORTS.TOTAL_EVALUATED') }}
                  </th>
                  <th class="py-2 text-right font-medium text-n-slate-11">
                    {{ t('CRM.EVALUATION_REPORTS.NO_RESPONSE_COUNT') }}
                  </th>
                  <th class="py-2 text-right font-medium text-n-slate-11">
                    {{ t('CRM.EVALUATION_REPORTS.ABANDONMENT_COUNT') }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <template v-for="agent in ranking" :key="agent.user_id">
                  <tr
                    class="border-b border-n-weak last:border-0 cursor-pointer hover:bg-n-alpha-1"
                    @click="toggleAgentDetail(agent.user_id)"
                  >
                    <td class="py-2 text-n-slate-12">
                      {{ agentName(agent.user_id) }}
                    </td>
                    <td
                      class="py-2 text-right font-semibold"
                      :class="scoreColor(agent.avg_score)"
                    >
                      {{ agent.avg_score ?? '--' }}
                    </td>
                    <td class="py-2 text-right">
                      <span
                        class="inline-flex items-center gap-1"
                        :class="trendColor(agent.trend)"
                      >
                        <span :class="trendIcon(agent.trend)" class="size-4" />
                        {{
                          t(
                            `CRM.EVALUATION_REPORTS.TREND_${agent.trend?.toUpperCase() || 'STABLE'}`
                          )
                        }}
                      </span>
                    </td>
                    <td class="py-2 text-right text-n-slate-12">
                      {{ agent.total_evaluated }}
                    </td>
                    <td class="py-2 text-right">
                      <span
                        :class="
                          agent.no_response_count > 0
                            ? 'text-n-ruby-11 font-medium'
                            : 'text-n-slate-12'
                        "
                      >
                        {{ agent.no_response_count }}
                      </span>
                    </td>
                    <td class="py-2 text-right">
                      <span
                        :class="
                          agent.abandonment_count > 0
                            ? 'text-n-amber-11 font-medium'
                            : 'text-n-slate-12'
                        "
                      >
                        {{ agent.abandonment_count }}
                      </span>
                    </td>
                  </tr>

                  <!-- Expanded Agent Detail -->
                  <tr v-if="expandedAgentId === agent.user_id && agentReport">
                    <td colspan="6" class="p-4 bg-n-alpha-1">
                      <div class="flex flex-col gap-3">
                        <div
                          v-if="agentReport.data?.highlights?.length"
                          class="flex flex-col gap-1"
                        >
                          <span class="text-xs font-medium text-n-teal-11">
                            {{ t('CRM.EVALUATION_REPORTS.BEST_CRITERIA') }}
                          </span>
                          <div class="flex flex-wrap gap-2">
                            <span
                              v-for="h in agentReport.data.highlights"
                              :key="h.criterion"
                              class="rounded-md bg-n-teal-3 px-2 py-0.5 text-xs text-n-teal-11"
                            >
                              {{ criterionLabel(h.criterion) }}:
                              {{ h.avg_score }}
                            </span>
                          </div>
                        </div>
                        <div
                          v-if="agentReport.data?.improvements?.length"
                          class="flex flex-col gap-1"
                        >
                          <span class="text-xs font-medium text-n-ruby-11">
                            {{ t('CRM.EVALUATION_REPORTS.WORST_CRITERIA') }}
                          </span>
                          <div class="flex flex-wrap gap-2">
                            <span
                              v-for="im in agentReport.data.improvements"
                              :key="im.criterion"
                              class="rounded-md bg-n-ruby-3 px-2 py-0.5 text-xs text-n-ruby-11"
                            >
                              {{ criterionLabel(im.criterion) }}:
                              {{ im.avg_score }}
                            </span>
                          </div>
                        </div>
                        <div
                          v-if="agentReport.data?.weekly_goal"
                          class="flex items-center gap-2"
                        >
                          <span class="text-xs font-medium text-n-slate-11">
                            {{ t('CRM.EVALUATION_REPORTS.WEEKLY_GOAL') }}:
                          </span>
                          <span class="text-xs text-n-slate-12">
                            {{
                              criterionLabel(
                                agentReport.data.weekly_goal.criterion
                              )
                            }}
                            ({{ agentReport.data.weekly_goal.current_avg }})
                          </span>
                        </div>
                      </div>
                    </td>
                  </tr>
                </template>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- TAB: Management -->
      <div v-if="activeTab === 'management'" class="flex flex-col gap-4">
        <!-- Aggregated Metrics -->
        <div class="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-5">
          <div
            class="flex flex-col gap-1 rounded-xl bg-n-solid-2 p-4 outline outline-1 outline-n-container"
          >
            <span class="text-xs text-n-slate-11">{{
              t('CRM.EVALUATION_REPORTS.MANAGEMENT.TEAM_AVG')
            }}</span>
            <span
              class="text-lg font-bold"
              :class="scoreColor(aggregated.team_avg_score)"
            >
              {{ aggregated.team_avg_score ?? '--' }}
            </span>
          </div>
          <div
            class="flex flex-col gap-1 rounded-xl bg-n-solid-2 p-4 outline outline-1 outline-n-container"
          >
            <span class="text-xs text-n-slate-11">{{
              t('CRM.EVALUATION_REPORTS.MANAGEMENT.TPR_AVG')
            }}</span>
            <span class="text-lg font-bold text-n-slate-12">
              {{ formatMinutes(aggregated.avg_tpr_seconds) }}
            </span>
          </div>
          <div
            class="flex flex-col gap-1 rounded-xl bg-n-solid-2 p-4 outline outline-1 outline-n-container"
          >
            <span class="text-xs text-n-slate-11">{{
              t('CRM.EVALUATION_REPORTS.TOTAL_EVALUATED')
            }}</span>
            <span class="text-lg font-bold text-n-slate-12">{{
              aggregated.total_evaluated || 0
            }}</span>
          </div>
          <div
            class="flex flex-col gap-1 rounded-xl bg-n-solid-2 p-4 outline outline-1 outline-n-container"
          >
            <span class="text-xs text-n-slate-11">{{
              t('CRM.EVALUATION_REPORTS.MANAGEMENT.ABANDONMENT_RATE')
            }}</span>
            <span class="text-lg font-bold text-n-amber-11"
              >{{ aggregated.abandonment_rate || 0 }}%</span
            >
          </div>
          <div
            class="flex flex-col gap-1 rounded-xl bg-n-solid-2 p-4 outline outline-1 outline-n-container"
          >
            <span class="text-xs text-n-slate-11">{{
              t('CRM.EVALUATION_REPORTS.MANAGEMENT.NO_RESPONSE_RATE')
            }}</span>
            <span class="text-lg font-bold text-n-ruby-11"
              >{{ aggregated.no_response_rate || 0 }}%</span
            >
          </div>
        </div>

        <!-- Systemic Issues -->
        <div
          v-if="systemicIssues.length"
          class="p-6 rounded-xl bg-n-solid-2 outline outline-1 outline-n-container"
        >
          <h2 class="mb-4 text-base font-semibold text-n-ruby-11">
            {{ t('CRM.EVALUATION_REPORTS.MANAGEMENT.SYSTEMIC_ISSUES') }}
          </h2>
          <div class="flex flex-col gap-2">
            <div
              v-for="issue in systemicIssues"
              :key="issue.criterion"
              class="flex items-center justify-between gap-3 rounded-lg bg-n-ruby-2 p-3"
            >
              <span class="min-w-0 truncate text-sm text-n-ruby-11">
                {{ criterionLabel(issue.criterion) }}
              </span>
              <span class="shrink-0 text-xs text-n-ruby-11 whitespace-nowrap">
                {{
                  t('CRM.EVALUATION_REPORTS.MANAGEMENT.SYSTEMIC_ISSUE_DETAIL', {
                    avgPercent: (issue.avg_normalized * 100).toFixed(0),
                    agentsCount: issue.agents_below_50pct,
                  })
                }}
              </span>
            </div>
          </div>
        </div>

        <!-- Weekly Evolution -->
        <div
          v-if="weeklyEvolution.length"
          class="p-6 rounded-xl bg-n-solid-2 outline outline-1 outline-n-container"
        >
          <h2 class="mb-4 text-base font-semibold text-n-slate-12">
            {{ t('CRM.EVALUATION_REPORTS.MANAGEMENT.WEEKLY_EVOLUTION') }}
          </h2>
          <div class="flex items-end gap-2 h-32">
            <div
              v-for="week in weeklyEvolution"
              :key="week.week_start"
              class="flex flex-1 flex-col items-center gap-1"
            >
              <span
                class="text-xs font-medium"
                :class="scoreColor(week.avg_score)"
              >
                {{ week.avg_score ?? '--' }}
              </span>
              <div
                class="w-full rounded-t-md transition-all"
                :class="
                  week.avg_score >= 7
                    ? 'bg-n-teal-9'
                    : week.avg_score >= 4
                      ? 'bg-n-amber-9'
                      : 'bg-n-ruby-9'
                "
                :style="{
                  height: `${Math.max(Math.round((week.avg_score || 0) * 10), 4)}px`,
                }"
              />
              <span class="text-[10px] text-n-slate-10 whitespace-nowrap">
                {{ week.count }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- TAB: Conversations -->
      <div v-if="activeTab === 'conversations'" class="flex flex-col gap-4">
        <!-- Worst Conversations -->
        <div
          v-if="worstConversations.length"
          class="p-6 rounded-xl bg-n-solid-2 outline outline-1 outline-n-container"
        >
          <h2 class="mb-4 text-base font-semibold text-n-ruby-11">
            {{ t('CRM.EVALUATION_REPORTS.MANAGEMENT.WORST_CONVERSATIONS') }}
          </h2>
          <div class="flex flex-col gap-2">
            <div
              v-for="conv in worstConversations"
              :key="conv.conversation_id"
              class="flex items-center justify-between rounded-lg bg-n-alpha-1 p-3"
            >
              <div class="flex min-w-0 flex-1 flex-col gap-0.5">
                <span class="text-sm font-medium text-n-slate-12">
                  #{{ conv.conversation_id }}
                </span>
                <span
                  v-if="conv.feedback"
                  class="text-xs text-n-slate-11 line-clamp-1"
                >
                  {{ conv.feedback }}
                </span>
              </div>
              <div class="flex shrink-0 items-center gap-3">
                <span class="text-xs text-n-slate-11 whitespace-nowrap">
                  {{ agentName(conv.assignee_id) }}
                </span>
                <span
                  class="text-sm font-bold"
                  :class="scoreColor(conv.final_score)"
                >
                  {{ conv.final_score }}
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Best Conversations -->
        <div
          v-if="bestConversations.length"
          class="p-6 rounded-xl bg-n-solid-2 outline outline-1 outline-n-container"
        >
          <h2 class="mb-4 text-base font-semibold text-n-teal-11">
            {{ t('CRM.EVALUATION_REPORTS.MANAGEMENT.BEST_CONVERSATIONS') }}
          </h2>
          <div class="flex flex-col gap-2">
            <div
              v-for="conv in bestConversations"
              :key="conv.conversation_id"
              class="flex items-center justify-between rounded-lg bg-n-alpha-1 p-3"
            >
              <div class="flex min-w-0 flex-1 flex-col gap-0.5">
                <span class="text-sm font-medium text-n-slate-12">
                  #{{ conv.conversation_id }}
                </span>
                <span
                  v-if="conv.feedback"
                  class="text-xs text-n-slate-11 line-clamp-1"
                >
                  {{ conv.feedback }}
                </span>
              </div>
              <div class="flex shrink-0 items-center gap-3">
                <span class="text-xs text-n-slate-11 whitespace-nowrap">
                  {{ agentName(conv.assignee_id) }}
                </span>
                <span
                  class="text-sm font-bold"
                  :class="scoreColor(conv.final_score)"
                >
                  {{ conv.final_score }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>

    <div
      v-else
      class="flex flex-col items-center justify-center py-16 text-n-slate-10"
    >
      <span class="i-lucide-bar-chart-3 size-12 mb-3" />
      <p class="text-sm">{{ t('CRM.EVALUATION_REPORTS.NO_DATA') }}</p>
    </div>
  </div>
</template>
