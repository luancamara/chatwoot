<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  // Reports that cannot honour a filter hide it rather than showing a control
  // that silently does nothing.
  showAgent: { type: Boolean, default: true },
  showTeam: { type: Boolean, default: true },
});

const emit = defineEmits(['filter-change']);
const { t } = useI18n();
const store = useStore();

const agents = useMapGetter('agents/getAgents');
const teams = useMapGetter('teams/getTeams');
const inboxes = useMapGetter('inboxes/getInboxes');

const sinceDate = ref('');
const untilDate = ref('');
const selectedAgentId = ref('');
const selectedTeamId = ref('');
const selectedInboxId = ref('');

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('teams/get');
  store.dispatch('inboxes/get');

  const now = new Date();
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  sinceDate.value = formatDate(thirtyDaysAgo);
  untilDate.value = formatDate(now);
  applyFilters();
});

const formatDate = date => {
  return date.toISOString().split('T')[0];
};

const applyFilters = () => {
  const params = {};
  // A bare 'YYYY-MM-DD' parses as UTC midnight, which in BRT lands on the
  // previous evening and drops the whole selected end day, today included.
  if (sinceDate.value) {
    params.since = Math.floor(
      new Date(`${sinceDate.value}T00:00:00`).getTime() / 1000
    );
  }
  if (untilDate.value) {
    params.until = Math.floor(
      new Date(`${untilDate.value}T23:59:59`).getTime() / 1000
    );
  }
  if (selectedAgentId.value) params.agent_id = selectedAgentId.value;
  if (selectedTeamId.value) params.team_id = selectedTeamId.value;
  if (selectedInboxId.value) params.inbox_id = selectedInboxId.value;
  emit('filter-change', params);
};
</script>

<template>
  <div class="flex flex-wrap gap-3 items-end mb-6">
    <div class="flex flex-col gap-1">
      <label class="text-xs font-medium text-n-slate-11">
        {{ t('CRM.FILTERS.DATE_RANGE') }}
      </label>
      <div class="flex gap-2 items-center">
        <Input
          v-model="sinceDate"
          type="date"
          size="sm"
        />
        <span class="text-n-slate-10">-</span>
        <Input
          v-model="untilDate"
          type="date"
          size="sm"
        />
      </div>
    </div>
    <div v-if="props.showAgent" class="flex flex-col gap-1 w-40">
      <label class="text-xs font-medium text-n-slate-11">
        {{ t('CRM.FILTERS.AGENT') }}
      </label>
      <ComboBox
        v-model="selectedAgentId"
        :options="[
          { value: '', label: t('CRM.FILTERS.ALL_AGENTS') },
          ...agents.map(a => ({ value: a.id, label: a.name })),
        ]"
        :placeholder="t('CRM.FILTERS.ALL_AGENTS')"
        size="sm"
      />
    </div>
    <div v-if="props.showTeam" class="flex flex-col gap-1 w-40">
      <label class="text-xs font-medium text-n-slate-11">
        {{ t('CRM.FILTERS.TEAM') }}
      </label>
      <ComboBox
        v-model="selectedTeamId"
        :options="[
          { value: '', label: t('CRM.FILTERS.ALL_TEAMS') },
          ...teams.map(team => ({ value: team.id, label: team.name })),
        ]"
        :placeholder="t('CRM.FILTERS.ALL_TEAMS')"
        size="sm"
      />
    </div>
    <div class="flex flex-col gap-1 w-40">
      <label class="text-xs font-medium text-n-slate-11">
        {{ t('CRM.FILTERS.INBOX') }}
      </label>
      <ComboBox
        v-model="selectedInboxId"
        :options="[
          { value: '', label: t('CRM.FILTERS.ALL_INBOXES') },
          ...inboxes.map(i => ({ value: i.id, label: i.name })),
        ]"
        :placeholder="t('CRM.FILTERS.ALL_INBOXES')"
        size="sm"
      />
    </div>
    <Button
      :label="t('CRM.FILTERS.APPLY')"
      size="sm"
      @click="applyFilters"
    />
  </div>
</template>
