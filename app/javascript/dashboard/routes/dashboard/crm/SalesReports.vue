<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import CrmFilters from './components/CrmFilters.vue';
import SalesMetricCard from './components/SalesMetricCard.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { dispositionLabel, lossReasonLabel } from './constants';

const { t } = useI18n();
const store = useStore();

const agentPerformance = useMapGetter('crm/reports/getAgentPerformance');
const dispositionBreakdown = useMapGetter('crm/reports/getDispositionBreakdown');
const uiFlags = useMapGetter('crm/reports/getUIFlags');
const allAgents = useMapGetter('agents/getAgents');

const isLoading = computed(
  () =>
    uiFlags.value.isFetchingAgentPerformance ||
    uiFlags.value.isFetchingDispositionBreakdown
);

const dispositionResults = computed(
  () => dispositionBreakdown.value?.dispositionResults || []
);
const lossReasons = computed(
  () => dispositionBreakdown.value?.lossReasons || []
);
const totalResolved = computed(
  () => dispositionBreakdown.value?.totalResolved || 0
);

const hasData = computed(
  () => agentPerformance.value.length > 0 || totalResolved.value > 0
);

const maxDispositionCount = computed(() =>
  Math.max(...dispositionResults.value.map(d => d.count), 1)
);

const maxLossCount = computed(() =>
  Math.max(...lossReasons.value.map(l => l.count), 1)
);

const agentName = agentId => {
  const agent = allAgents.value.find(a => a.id === agentId);
  return agent?.name || `Agent #${agentId}`;
};

const formatCurrency = value => {
  if (!value) return 'R$ 0';
  return `R$ ${Number(value).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`;
};

const onFilterChange = params => {
  store.dispatch('crm/reports/fetchAgentPerformance', params);
  store.dispatch('crm/reports/fetchDispositionBreakdown', params);
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <div>
      <h1 class="text-xl font-semibold text-n-slate-12">
        {{ t('CRM.SALES_REPORTS.TITLE') }}
      </h1>
      <p class="mt-1 text-sm text-n-slate-11">
        {{ t('CRM.SALES_REPORTS.DESCRIPTION') }}
      </p>
    </div>

    <CrmFilters @filter-change="onFilterChange" />

    <div v-if="isLoading" class="flex justify-center py-12">
      <Spinner />
    </div>

    <template v-else-if="hasData">
      <div class="grid grid-cols-2 gap-4 md:grid-cols-4">
        <SalesMetricCard
          :label="t('CRM.SALES_REPORTS.TOTAL_CONVERSATIONS')"
          :value="agentPerformance.reduce((s, a) => s + a.totalConversations, 0)"
        />
        <SalesMetricCard
          :label="t('CRM.SALES_REPORTS.RESOLVED')"
          :value="totalResolved"
        />
        <SalesMetricCard
          :label="t('CRM.SALES_REPORTS.VENDAS')"
          :value="dispositionResults.find(d => d.result === 'Venda')?.count || 0"
        />
        <SalesMetricCard
          :label="t('CRM.SALES_REPORTS.CONVERSION_RATE')"
          :value="
            totalResolved > 0
              ? `${((dispositionResults.find(d => d.result === 'Venda')?.count || 0) / totalResolved * 100).toFixed(1)}%`
              : '0%'
          "
        />
      </div>

      <!-- Agent Ranking Table -->
      <div
        v-if="agentPerformance.length"
        class="p-6 rounded-xl bg-n-solid-2 outline outline-1 outline-n-container"
      >
        <h2 class="mb-4 text-base font-semibold text-n-slate-12">
          {{ t('CRM.SALES_REPORTS.AGENT_RANKING') }}
        </h2>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-n-weak">
                <th class="py-2 text-left font-medium text-n-slate-11">
                  {{ t('CRM.SALES_REPORTS.AGENT') }}
                </th>
                <th class="py-2 text-right font-medium text-n-slate-11">
                  {{ t('CRM.SALES_REPORTS.TOTAL_CONVERSATIONS') }}
                </th>
                <th class="py-2 text-right font-medium text-n-slate-11">
                  {{ t('CRM.SALES_REPORTS.RESOLVED') }}
                </th>
                <th class="py-2 text-right font-medium text-n-slate-11">
                  {{ t('CRM.SALES_REPORTS.VENDAS') }}
                </th>
                <th class="py-2 text-right font-medium text-n-slate-11">
                  {{ t('CRM.SALES_REPORTS.CONVERSION_RATE') }}
                </th>
                <th class="py-2 text-right font-medium text-n-slate-11">
                  {{ t('CRM.SALES_REPORTS.AVG_QUALITY_SCORE') }}
                </th>
                <th class="py-2 text-right font-medium text-n-slate-11">
                  {{ t('CRM.SALES_REPORTS.TOTAL_REVENUE') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="agent in agentPerformance"
                :key="agent.id"
                class="border-b border-n-weak last:border-0"
              >
                <td class="py-2 text-n-slate-12">{{ agentName(agent.id) }}</td>
                <td class="py-2 text-right text-n-slate-12">
                  {{ agent.totalConversations }}
                </td>
                <td class="py-2 text-right text-n-slate-12">
                  {{ agent.resolvedConversations }}
                </td>
                <td class="py-2 text-right text-n-slate-12">
                  {{ agent.vendasCount }}
                </td>
                <td class="py-2 text-right text-n-slate-12">
                  {{ agent.conversionRate }}%
                </td>
                <td class="py-2 text-right text-n-slate-12">
                  {{ agent.avgQualityScore || t('CRM.SALES_REPORTS.NA') }}
                </td>
                <td class="py-2 text-right text-n-slate-12">
                  {{ formatCurrency(agent.totalEstimatedRevenue) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Disposition Breakdown -->
      <div
        v-if="dispositionResults.length"
        class="p-6 rounded-xl bg-n-solid-2 outline outline-1 outline-n-container"
      >
        <h2 class="mb-4 text-base font-semibold text-n-slate-12">
          {{ t('CRM.SALES_REPORTS.DISPOSITION_BREAKDOWN') }}
        </h2>
        <div class="flex flex-col gap-3">
          <div
            v-for="item in dispositionResults"
            :key="item.result"
            class="flex items-center gap-3"
          >
            <span class="w-28 text-sm text-n-slate-12 shrink-0 truncate">
              {{ dispositionLabel(item.result) }}
            </span>
            <div class="flex-1 h-6 bg-n-alpha-1 rounded-md overflow-hidden">
              <div
                class="h-full rounded-md flex items-center px-2 transition-all duration-300"
                :class="{
                  'bg-n-teal': item.result === 'Venda',
                  'bg-n-ruby': item.result === 'Perda',
                  'bg-n-amber': item.result === 'Indecisao',
                  'bg-n-slate-8': item.result === 'Sem Resposta',
                }"
                :style="{ width: `${Math.max((item.count / maxDispositionCount) * 100, 2)}%` }"
              >
                <span class="text-xs font-medium text-white whitespace-nowrap">
                  {{ item.count }}
                </span>
              </div>
            </div>
            <span class="text-xs text-n-slate-10 w-12 text-right">
              {{ totalResolved > 0 ? `${((item.count / totalResolved) * 100).toFixed(0)}%` : '0%' }}
            </span>
          </div>
        </div>
      </div>

      <!-- Loss Reasons -->
      <div
        v-if="lossReasons.some(l => l.count > 0)"
        class="p-6 rounded-xl bg-n-solid-2 outline outline-1 outline-n-container"
      >
        <h2 class="mb-4 text-base font-semibold text-n-slate-12">
          {{ t('CRM.SALES_REPORTS.LOSS_REASONS') }}
        </h2>
        <div class="flex flex-col gap-3">
          <div
            v-for="item in lossReasons"
            :key="item.reason"
            class="flex items-center gap-3"
          >
            <span class="w-28 text-sm text-n-slate-12 shrink-0 truncate">
              {{ lossReasonLabel(item.reason) }}
            </span>
            <div class="flex-1 h-6 bg-n-alpha-1 rounded-md overflow-hidden">
              <div
                class="h-full bg-n-ruby rounded-md flex items-center px-2 transition-all duration-300"
                :style="{ width: `${Math.max((item.count / maxLossCount) * 100, 2)}%` }"
              >
                <span class="text-xs font-medium text-white whitespace-nowrap">
                  {{ item.count }}
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
      <p class="text-sm">{{ t('CRM.SALES_REPORTS.NO_DATA') }}</p>
    </div>
  </div>
</template>
