<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useFunctionGetter, useStore } from 'dashboard/composables/store';
import CrmReportsAPI from 'dashboard/api/crmReports';

import WootReports from './components/WootReports.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const route = useRoute();
const store = useStore();
const { t } = useI18n();
const agent = useFunctionGetter('agents/getAgentById', route.params.id);

const qualityScore = ref(null);
const isFetchingScore = ref(false);

const fetchQualityScore = async agentId => {
  if (!agentId) return;
  isFetchingScore.value = true;
  try {
    const response = await CrmReportsAPI.getAgentPerformance({
      agent_id: agentId,
    });
    const agentData = response.data.find(a => a.id === agentId);
    qualityScore.value = agentData?.avg_quality_score ?? null;
  } catch {
    qualityScore.value = null;
  } finally {
    isFetchingScore.value = false;
  }
};

const scoreDisplay = computed(() => {
  if (qualityScore.value === null) return t('CRM.SALES_REPORTS.NA');
  return `${qualityScore.value} / 10`;
});

onMounted(() => {
  store.dispatch('agents/get');
});

watch(
  () => agent.value?.id,
  newId => {
    if (newId) fetchQualityScore(newId);
  },
  { immediate: true }
);
</script>

<template>
  <div v-if="agent.id">
    <WootReports
      :key="agent.id"
      type="agent"
      getter-key="agents/getAgents"
      action-key="agents/get"
      :selected-item="agent"
      :download-button-label="$t('AGENT_REPORTS.DOWNLOAD_AGENT_REPORTS')"
      :report-title="$t('AGENT_REPORTS.HEADER')"
      has-back-button
    />
    <div class="px-8 pb-6">
      <div
        class="p-4 rounded-xl bg-n-solid-2 outline outline-1 outline-n-container"
      >
        <h3 class="text-sm font-medium text-n-slate-11 mb-1">
          {{ t('CRM.SALES_REPORTS.AVG_QUALITY_SCORE') }}
        </h3>
        <div v-if="isFetchingScore" class="flex items-center gap-2">
          <Spinner class="size-4" />
        </div>
        <p v-else class="text-xl font-semibold text-n-slate-12 m-0">
          {{ scoreDisplay }}
        </p>
      </div>
    </div>
  </div>
  <div v-else class="w-full py-20">
    <Spinner class="mx-auto" />
  </div>
</template>
