<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import CrmFilters from './components/CrmFilters.vue';
import FunnelChart from './components/FunnelChart.vue';
import SalesMetricCard from './components/SalesMetricCard.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const store = useStore();

const funnel = useMapGetter('crm/reports/getFunnel');
const pipelineSummary = useMapGetter('crm/reports/getPipelineSummary');
const uiFlags = useMapGetter('crm/reports/getUIFlags');

const isLoading = computed(
  () => uiFlags.value.isFetchingFunnel || uiFlags.value.isFetchingPipelineSummary
);

const stages = computed(() => funnel.value?.stages || []);
const conversionRates = computed(() => funnel.value?.conversionRates || []);
const hasData = computed(() => stages.value.some(s => s.count > 0));

const totalConversations = computed(() =>
  stages.value.reduce((sum, s) => sum + s.count, 0)
);

const formatCurrency = value => {
  if (!value) return 'R$ 0';
  return `R$ ${Number(value).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`;
};

const onFilterChange = params => {
  store.dispatch('crm/reports/fetchFunnel', params);
  store.dispatch('crm/reports/fetchPipelineSummary', params);
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <div>
      <h1 class="text-xl font-semibold text-n-slate-12">
        {{ t('CRM.FUNNEL.TITLE') }}
      </h1>
      <p class="mt-1 text-sm text-n-slate-11">
        {{ t('CRM.FUNNEL.DESCRIPTION') }}
      </p>
    </div>

    <CrmFilters @filter-change="onFilterChange" />

    <div v-if="isLoading" class="flex justify-center py-12">
      <Spinner />
    </div>

    <template v-else-if="hasData">
      <div class="grid grid-cols-2 gap-4 md:grid-cols-4">
        <SalesMetricCard
          :label="t('CRM.FUNNEL.COUNT')"
          :value="totalConversations"
        />
        <SalesMetricCard
          v-for="stage in stages.filter(s => s.count > 0).slice(0, 3)"
          :key="stage.stage"
          :label="stage.stage"
          :value="stage.count"
        />
      </div>

      <div class="p-6 rounded-xl bg-n-solid-2 outline outline-1 outline-n-container">
        <h2 class="mb-4 text-base font-semibold text-n-slate-12">
          {{ t('CRM.FUNNEL.TITLE') }}
        </h2>
        <FunnelChart
          :stages="stages"
          :conversion-rates="conversionRates"
        />
      </div>

      <div
        v-if="pipelineSummary.length"
        class="p-6 rounded-xl bg-n-solid-2 outline outline-1 outline-n-container"
      >
        <h2 class="mb-4 text-base font-semibold text-n-slate-12">
          {{ t('CRM.FUNNEL.PIPELINE_SUMMARY') }}
        </h2>
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-n-weak">
              <th class="py-2 text-left font-medium text-n-slate-11">
                {{ t('CRM.FUNNEL.STAGE') }}
              </th>
              <th class="py-2 text-right font-medium text-n-slate-11">
                {{ t('CRM.FUNNEL.COUNT') }}
              </th>
              <th class="py-2 text-right font-medium text-n-slate-11">
                {{ t('CRM.FUNNEL.ESTIMATED_VALUE') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="item in pipelineSummary"
              :key="item.stage"
              class="border-b border-n-weak last:border-0"
            >
              <td class="py-2 text-n-slate-12">{{ item.stage }}</td>
              <td class="py-2 text-right text-n-slate-12">{{ item.count }}</td>
              <td class="py-2 text-right text-n-slate-12">
                {{ formatCurrency(item.estimatedValue) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>

    <div
      v-else
      class="flex flex-col items-center justify-center py-16 text-n-slate-10"
    >
      <span class="i-lucide-bar-chart-3 size-12 mb-3" />
      <p class="text-sm">{{ t('CRM.FUNNEL.NO_DATA') }}</p>
    </div>
  </div>
</template>
