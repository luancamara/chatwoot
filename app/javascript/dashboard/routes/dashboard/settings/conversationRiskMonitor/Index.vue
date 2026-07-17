<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import ConversationRiskMonitorsAPI from 'dashboard/api/conversationRiskMonitors';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const store = useStore();
const { t } = useI18n();

const isLoading = ref(true);
const isSaving = ref(false);
const configs = ref([]);
const selectedInboxId = ref(null);
const form = ref({
  enabled: false,
  management_team_id: null,
  complaint_label_id: null,
  critical_label_id: null,
});

const inboxes = computed(() =>
  store.getters['inboxes/getInboxes'].filter(
    inbox => inbox.channel_type === INBOX_TYPES.WHATSAPP
  )
);
const teams = computed(() => store.getters['teams/getTeams']);
const labels = computed(() => store.getters['labels/getLabels']);
const canSave = computed(
  () =>
    selectedInboxId.value &&
    (!form.value.enabled ||
      (form.value.management_team_id &&
        form.value.complaint_label_id &&
        form.value.critical_label_id))
);

const loadSelectedConfig = () => {
  const config = configs.value.find(
    item => item.inbox_id === Number(selectedInboxId.value)
  );
  form.value = {
    enabled: config?.enabled || false,
    management_team_id: config?.management_team_id || null,
    complaint_label_id: config?.complaint_label_id || null,
    critical_label_id: config?.critical_label_id || null,
  };
};

watch(selectedInboxId, loadSelectedConfig);

const save = async () => {
  if (!canSave.value) return;

  isSaving.value = true;
  try {
    const { data } = await ConversationRiskMonitorsAPI.update(
      selectedInboxId.value,
      form.value
    );
    configs.value = [
      ...configs.value.filter(item => item.inbox_id !== data.inbox_id),
      data,
    ];
    useAlert(t('CONVERSATION_RISK_MONITOR.API.SUCCESS'));
  } catch (error) {
    useAlert(
      error?.response?.data?.message || t('CONVERSATION_RISK_MONITOR.API.ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

onMounted(async () => {
  try {
    const [, , , response] = await Promise.all([
      store.dispatch('inboxes/get'),
      store.dispatch('teams/get'),
      store.dispatch('labels/get'),
      ConversationRiskMonitorsAPI.get(),
    ]);
    configs.value = response.data;
    selectedInboxId.value =
      configs.value[0]?.inbox_id || inboxes.value[0]?.id || null;
    loadSelectedConfig();
  } catch (error) {
    useAlert(t('CONVERSATION_RISK_MONITOR.API.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('CONVERSATION_RISK_MONITOR.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('CONVERSATION_RISK_MONITOR.TITLE')"
        :description="t('CONVERSATION_RISK_MONITOR.DESCRIPTION')"
      />
    </template>

    <template #body>
      <div class="mt-6 grid gap-6">
        <section
          class="rounded-xl border border-n-weak bg-n-background p-5 shadow-sm"
        >
          <div class="flex items-start justify-between gap-6">
            <div>
              <h2 class="text-heading-2 text-n-slate-12">
                {{ t('CONVERSATION_RISK_MONITOR.STATUS.TITLE') }}
              </h2>
              <p class="mt-1 text-body-main text-n-slate-11">
                {{ t('CONVERSATION_RISK_MONITOR.STATUS.DESCRIPTION') }}
              </p>
            </div>
            <Switch v-model="form.enabled" />
          </div>
        </section>

        <section
          class="rounded-xl border border-n-weak bg-n-background p-5 shadow-sm"
        >
          <div class="mb-5">
            <h2 class="text-heading-2 text-n-slate-12">
              {{ t('CONVERSATION_RISK_MONITOR.ROUTING.TITLE') }}
            </h2>
            <p class="mt-1 text-body-main text-n-slate-11">
              {{ t('CONVERSATION_RISK_MONITOR.ROUTING.DESCRIPTION') }}
            </p>
          </div>

          <div class="grid gap-5 sm:grid-cols-2">
            <label class="grid gap-2 text-sm font-medium text-n-slate-12">
              {{ t('CONVERSATION_RISK_MONITOR.FIELDS.INBOX') }}
              <select
                v-model.number="selectedInboxId"
                class="h-10 rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option :value="null" disabled>
                  {{ t('CONVERSATION_RISK_MONITOR.FIELDS.SELECT') }}
                </option>
                <option
                  v-for="inbox in inboxes"
                  :key="inbox.id"
                  :value="inbox.id"
                >
                  {{ inbox.name }}
                </option>
              </select>
            </label>

            <label class="grid gap-2 text-sm font-medium text-n-slate-12">
              {{ t('CONVERSATION_RISK_MONITOR.FIELDS.TEAM') }}
              <select
                v-model.number="form.management_team_id"
                class="h-10 rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option :value="null" disabled>
                  {{ t('CONVERSATION_RISK_MONITOR.FIELDS.SELECT') }}
                </option>
                <option v-for="team in teams" :key="team.id" :value="team.id">
                  {{ team.name }}
                </option>
              </select>
            </label>

            <label class="grid gap-2 text-sm font-medium text-n-slate-12">
              {{ t('CONVERSATION_RISK_MONITOR.FIELDS.COMPLAINT_LABEL') }}
              <select
                v-model.number="form.complaint_label_id"
                class="h-10 rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option :value="null" disabled>
                  {{ t('CONVERSATION_RISK_MONITOR.FIELDS.SELECT') }}
                </option>
                <option
                  v-for="label in labels"
                  :key="label.id"
                  :value="label.id"
                >
                  {{ label.title }}
                </option>
              </select>
            </label>

            <label class="grid gap-2 text-sm font-medium text-n-slate-12">
              {{ t('CONVERSATION_RISK_MONITOR.FIELDS.CRITICAL_LABEL') }}
              <select
                v-model.number="form.critical_label_id"
                class="h-10 rounded-lg border border-n-weak bg-n-alpha-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
              >
                <option :value="null" disabled>
                  {{ t('CONVERSATION_RISK_MONITOR.FIELDS.SELECT') }}
                </option>
                <option
                  v-for="label in labels"
                  :key="label.id"
                  :value="label.id"
                >
                  {{ label.title }}
                </option>
              </select>
            </label>
          </div>
        </section>

        <aside
          class="rounded-xl border border-n-teal-7 bg-n-teal-2 p-5 text-n-slate-12"
        >
          <div class="flex gap-3">
            <span
              class="i-lucide-shield-check mt-0.5 size-5 shrink-0 text-n-teal-11"
            />
            <div>
              <h2 class="text-sm font-semibold">
                {{ t('CONVERSATION_RISK_MONITOR.SILENT.TITLE') }}
              </h2>
              <p class="mt-1 text-sm text-n-slate-11">
                {{ t('CONVERSATION_RISK_MONITOR.SILENT.DESCRIPTION') }}
              </p>
            </div>
          </div>
        </aside>

        <div class="flex justify-end">
          <Button
            :label="t('CONVERSATION_RISK_MONITOR.SAVE')"
            :is-loading="isSaving"
            :disabled="!canSave || isSaving"
            @click="save"
          />
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
