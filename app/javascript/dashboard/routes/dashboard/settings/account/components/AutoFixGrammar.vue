<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import SectionLayout from './SectionLayout.vue';
import Switch from 'next/switch/Switch.vue';

const { t } = useI18n();
const isEnabled = ref(false);

const { currentAccount, updateAccount } = useAccount();

watch(
  currentAccount,
  () => {
    const { auto_fix_grammar } = currentAccount.value?.settings || {};
    isEnabled.value = !!auto_fix_grammar;
  },
  { deep: true, immediate: true }
);

const updateAccountSettings = async settings => {
  try {
    await updateAccount(settings);
    useAlert(t('GENERAL_SETTINGS.FORM.AUTO_FIX_GRAMMAR.API.SUCCESS'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.FORM.AUTO_FIX_GRAMMAR.API.ERROR'));
  }
};

const toggleAutoFixGrammar = async () => {
  return updateAccountSettings({
    auto_fix_grammar: isEnabled.value,
  });
};
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.AUTO_FIX_GRAMMAR.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.AUTO_FIX_GRAMMAR.NOTE')"
    with-border
  >
    <template #headerActions>
      <div class="flex justify-end">
        <Switch v-model="isEnabled" @change="toggleAutoFixGrammar" />
      </div>
    </template>
  </SectionLayout>
</template>
