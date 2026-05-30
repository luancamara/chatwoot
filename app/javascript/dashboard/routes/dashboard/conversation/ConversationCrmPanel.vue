<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import {
  FUNNEL_STAGES,
  DISPOSITIONS,
  LOSS_REASONS,
  LOST_STAGE,
  LOST_DISPOSITION,
} from 'dashboard/routes/dashboard/crm/constants';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();
const currentChat = useMapGetter('getSelectedChat');

const customAttributes = computed(
  () => currentChat.value?.custom_attributes || {}
);

const stage = computed(() => customAttributes.value.crm_funnel_stage || '');
const disposition = computed(
  () => customAttributes.value.crm_disposition_result || ''
);
const lossReason = computed(() => customAttributes.value.crm_loss_reason || '');

const draftValue = ref('');
watch(
  () => customAttributes.value.crm_estimated_value,
  value => {
    draftValue.value = value ?? '';
  },
  { immediate: true }
);

const stageOptions = FUNNEL_STAGES;
const noneOption = computed(() => ({ value: '', label: t('CRM.DEAL.NONE') }));
const dispositionOptions = computed(() => [
  noneOption.value,
  ...DISPOSITIONS,
]);
const lossReasonOptions = computed(() => [noneOption.value, ...LOSS_REASONS]);

const showLossReason = computed(
  () => disposition.value === LOST_DISPOSITION || stage.value === LOST_STAGE
);

const persist = async patch => {
  const next = { ...customAttributes.value, ...patch };
  Object.keys(patch).forEach(key => {
    const value = patch[key];
    if (value === '' || value === null || value === undefined) {
      delete next[key];
    }
  });
  try {
    await store.dispatch('updateCustomAttributes', {
      conversationId: props.conversationId,
      customAttributes: next,
    });
  } catch {
    useAlert(t('CRM.DEAL.UPDATE_ERROR'));
  }
};

const onStageChange = value => {
  if (value === stage.value) return;
  persist({
    crm_funnel_stage: value,
    crm_stage_changed_at: new Date().toISOString(),
  });
};

const onDispositionChange = value => {
  if (value === disposition.value) return;
  persist({ crm_disposition_result: value });
};

const onLossReasonChange = value => {
  if (value === lossReason.value) return;
  persist({ crm_loss_reason: value });
};

const saveValue = () => {
  const current = customAttributes.value.crm_estimated_value ?? null;
  const parsed = parseFloat(String(draftValue.value).replace(',', '.'));
  const next = Number.isNaN(parsed) ? '' : parsed;
  if ((next === '' ? null : next) === current) return;
  persist({ crm_estimated_value: next });
};
</script>

<template>
  <div class="flex flex-col gap-4 px-1 py-2">
    <div class="flex flex-col gap-1">
      <label class="text-xs font-medium text-n-slate-11">
        {{ t('CRM.DEAL.STAGE') }}
      </label>
      <ComboBox
        :model-value="stage"
        :options="stageOptions"
        :placeholder="t('CRM.DEAL.STAGE_PLACEHOLDER')"
        size="sm"
        @update:model-value="onStageChange"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label class="text-xs font-medium text-n-slate-11">
        {{ t('CRM.DEAL.VALUE') }}
      </label>
      <Input
        v-model="draftValue"
        type="number"
        size="sm"
        :placeholder="t('CRM.DEAL.VALUE_PLACEHOLDER')"
        @keyup.enter="saveValue"
        @blur="saveValue"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label class="text-xs font-medium text-n-slate-11">
        {{ t('CRM.DEAL.DISPOSITION') }}
      </label>
      <ComboBox
        :model-value="disposition"
        :options="dispositionOptions"
        :placeholder="t('CRM.DEAL.DISPOSITION_PLACEHOLDER')"
        size="sm"
        @update:model-value="onDispositionChange"
      />
    </div>

    <div v-if="showLossReason" class="flex flex-col gap-1">
      <label class="text-xs font-medium text-n-slate-11">
        {{ t('CRM.DEAL.LOSS_REASON') }}
      </label>
      <ComboBox
        :model-value="lossReason"
        :options="lossReasonOptions"
        :placeholder="t('CRM.DEAL.LOSS_REASON_PLACEHOLDER')"
        size="sm"
        @update:model-value="onLossReasonChange"
      />
    </div>
  </div>
</template>
