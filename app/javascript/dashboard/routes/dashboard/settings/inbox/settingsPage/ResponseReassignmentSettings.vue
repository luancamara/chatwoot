<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Select from 'dashboard/components-next/select/Select.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';

const props = defineProps({ inbox: { type: Object, required: true } });
const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');
const mode = ref('disabled');
const manager = ref('');
const isSaving = ref(false);
const key = 'INBOX_MGMT.RESPONSE_REASSIGNMENT';
const modes = computed(() =>
  ['disabled', 'first_response', 'all_responses'].map(value => ({
    value,
    label: t(`${key}.MODES.${value.toUpperCase()}`),
  }))
);
const managers = computed(() =>
  agents.value
    .filter(agent => agent.role === 'administrator')
    .map(agent => ({ value: agent.id, label: agent.name }))
);
watch(
  () => props.inbox,
  inbox => {
    mode.value = inbox.response_reassignment_mode;
    manager.value = inbox.response_reassignment_notify_user_id ?? '';
  },
  { immediate: true }
);

const save = async () => {
  isSaving.value = true;
  try {
    await store.dispatch('inboxes/updateInbox', {
      id: props.inbox.id,
      formData: false,
      response_reassignment_mode: mode.value,
      response_reassignment_notify_user_id: manager.value || null,
    });
    useAlert(t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
  } catch {
    useAlert(t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <section class="flex flex-col gap-4 border-t border-n-weak py-6">
    <h3 class="text-heading-3 text-n-slate-12">{{ t(`${key}.TITLE`) }}</h3>
    <p class="text-body-main text-n-slate-11">{{ t(`${key}.DESCRIPTION`) }}</p>
    <WithLabel name="response-reassignment-mode" :label="t(`${key}.MODE`)">
      <Select
        id="response-reassignment-mode"
        v-model="mode"
        :options="modes"
        :aria-label="t(`${key}.MODE`)"
      />
    </WithLabel>
    <WithLabel
      v-if="mode !== 'disabled'"
      name="response-reassignment-manager"
      :label="t(`${key}.MANAGER`)"
    >
      <Select
        id="response-reassignment-manager"
        v-model="manager"
        :options="managers"
        :placeholder="t(`${key}.SELECT_MANAGER`)"
        :aria-label="t(`${key}.MANAGER`)"
      />
    </WithLabel>
    <p class="text-body-main text-n-slate-11">{{ t(`${key}.HELP`) }}</p>
    <Button
      :label="t(`${key}.SAVE`)"
      :is-loading="isSaving"
      :disabled="isSaving || (mode !== 'disabled' && !manager)"
      class="self-start"
      @click="save"
    />
  </section>
</template>
