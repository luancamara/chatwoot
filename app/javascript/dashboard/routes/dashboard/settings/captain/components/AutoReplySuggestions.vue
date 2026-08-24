<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ModelDropdown from './ModelDropdown.vue';

const emit = defineEmits(['modelChange']);

const { t } = useI18n();
const { currentAccount, updateAccount } = useAccount();

const isEnabled = ref(false);
const isUpdating = ref(false);
const customPrompt = ref('');
const savedCustomPrompt = ref('');

const isPromptDirty = computed(
  () => customPrompt.value.trim() !== savedCustomPrompt.value
);

watch(
  currentAccount,
  account => {
    isEnabled.value = !!account?.settings?.auto_reply_suggestions;
  },
  { deep: true, immediate: true }
);

watch(
  () => currentAccount.value?.settings?.reply_suggestion_prompt,
  prompt => {
    savedCustomPrompt.value = prompt?.trim() || '';
    customPrompt.value = savedCustomPrompt.value;
  },
  { immediate: true }
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

const saveCustomPrompt = async () => {
  isUpdating.value = true;
  try {
    await updateAccount({
      reply_suggestion_prompt: customPrompt.value.trim(),
    });
    useAlert(t('CAPTAIN_SETTINGS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('CAPTAIN_SETTINGS.API.ERROR'));
  } finally {
    isUpdating.value = false;
  }
};

const handleModelChange = payload => {
  emit('modelChange', payload);
};
</script>

<template>
  <div class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1">
    <div class="flex items-center justify-between gap-4 p-4">
      <div class="min-w-0 flex-1">
        <h4 class="text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN_SETTINGS.FEATURES.AUTO_REPLY_SUGGESTIONS.TITLE') }}
        </h4>
        <p class="mt-0.5 text-sm text-n-slate-11">
          {{
            t('CAPTAIN_SETTINGS.FEATURES.AUTO_REPLY_SUGGESTIONS.DESCRIPTION')
          }}
        </p>
      </div>
      <Switch
        v-model="isEnabled"
        :disabled="isUpdating"
        @change="toggleAutoReplySuggestions"
      />
    </div>

    <div class="grid gap-5 border-t border-n-weak bg-n-alpha-1 p-4">
      <div class="flex items-center justify-between gap-4">
        <div class="min-w-0 flex-1">
          <h5 class="text-sm font-medium text-n-slate-12">
            {{
              t('CAPTAIN_SETTINGS.FEATURES.AUTO_REPLY_SUGGESTIONS.MODEL_TITLE')
            }}
          </h5>
          <p class="mt-0.5 text-sm text-n-slate-11">
            {{
              t(
                'CAPTAIN_SETTINGS.FEATURES.AUTO_REPLY_SUGGESTIONS.MODEL_DESCRIPTION'
              )
            }}
          </p>
        </div>
        <ModelDropdown
          feature-key="reply_suggestion"
          @change="handleModelChange"
        />
      </div>

      <div class="grid gap-2">
        <div>
          <label
            for="reply-suggestion-prompt"
            class="text-sm font-medium text-n-slate-12"
          >
            {{
              t('CAPTAIN_SETTINGS.FEATURES.AUTO_REPLY_SUGGESTIONS.PROMPT_TITLE')
            }}
          </label>
          <p class="mt-0.5 text-sm text-n-slate-11">
            {{
              t(
                'CAPTAIN_SETTINGS.FEATURES.AUTO_REPLY_SUGGESTIONS.PROMPT_DESCRIPTION'
              )
            }}
          </p>
        </div>
        <textarea
          id="reply-suggestion-prompt"
          v-model="customPrompt"
          rows="4"
          maxlength="4000"
          :disabled="isUpdating"
          :placeholder="
            t(
              'CAPTAIN_SETTINGS.FEATURES.AUTO_REPLY_SUGGESTIONS.PROMPT_PLACEHOLDER'
            )
          "
          class="w-full resize-y rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10 hover:border-n-slate-6 focus:border-n-brand disabled:cursor-not-allowed disabled:opacity-50"
        />
        <div class="flex items-center justify-between gap-3">
          <span class="text-xs tabular-nums text-n-slate-10">
            {{
              t(
                'CAPTAIN_SETTINGS.FEATURES.AUTO_REPLY_SUGGESTIONS.CHARACTER_COUNT',
                { count: customPrompt.length, limit: 4000 }
              )
            }}
          </span>
          <Button
            type="button"
            size="sm"
            :disabled="!isPromptDirty || isUpdating"
            :is-loading="isUpdating"
            :label="
              t('CAPTAIN_SETTINGS.FEATURES.AUTO_REPLY_SUGGESTIONS.SAVE_PROMPT')
            "
            @click="saveCustomPrompt"
          />
        </div>
      </div>
    </div>
  </div>
</template>
