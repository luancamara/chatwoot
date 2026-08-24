<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const { t } = useI18n();
const { currentAccount, updateAccount } = useAccount();

const isEnabled = ref(false);
const isUpdating = ref(false);

watch(
  currentAccount,
  account => {
    isEnabled.value = !!account?.settings?.auto_reply_suggestions;
  },
  { deep: true, immediate: true }
);

const toggleAutoReplySuggestions = async () => {
  const nextValue = isEnabled.value;
  isUpdating.value = true;
  try {
    await updateAccount({ auto_reply_suggestions: nextValue });
    useAlert(t('CAPTAIN_SETTINGS.API.SUCCESS'));
  } catch (error) {
    isEnabled.value = !nextValue;
    useAlert(t('CAPTAIN_SETTINGS.API.ERROR'));
  } finally {
    isUpdating.value = false;
  }
};
</script>

<template>
  <div
    class="flex items-center justify-between gap-4 rounded-xl border border-n-weak bg-n-solid-1 p-4"
  >
    <div class="min-w-0 flex-1">
      <h4 class="text-sm font-medium text-n-slate-12">
        {{ t('CAPTAIN_SETTINGS.FEATURES.AUTO_REPLY_SUGGESTIONS.TITLE') }}
      </h4>
      <p class="mt-0.5 text-sm text-n-slate-11">
        {{ t('CAPTAIN_SETTINGS.FEATURES.AUTO_REPLY_SUGGESTIONS.DESCRIPTION') }}
      </p>
    </div>
    <Switch
      v-model="isEnabled"
      :disabled="isUpdating"
      @change="toggleAutoReplySuggestions"
    />
  </div>
</template>
