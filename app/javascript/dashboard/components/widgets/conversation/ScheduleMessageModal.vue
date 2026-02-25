<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ScheduledMessagesAPI from 'dashboard/api/scheduledMessages';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  messageContent: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['close', 'scheduled']);

const { t } = useI18n();
const scheduledAt = ref('');
const messageText = ref('');
const isSubmitting = ref(false);

onMounted(() => {
  messageText.value = props.messageContent || '';
});

const minDateTime = computed(() => {
  const now = new Date();
  now.setMinutes(now.getMinutes() + 5);
  return now.toISOString().slice(0, 16);
});

const isValid = computed(() => {
  return scheduledAt.value && messageText.value?.trim();
});

const handleSchedule = async () => {
  if (!isValid.value || isSubmitting.value) return;

  try {
    isSubmitting.value = true;
    await ScheduledMessagesAPI.create(props.conversationId, {
      content: messageText.value,
      scheduled_at: new Date(scheduledAt.value).toISOString(),
    });
    useAlert(t('CONVERSATION.SCHEDULE_MESSAGE.API.SUCCESS'));
    emit('scheduled');
    emit('close');
  } catch {
    useAlert(t('CONVERSATION.SCHEDULE_MESSAGE.API.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    @click.self="$emit('close')"
  >
    <div
      class="mx-4 w-full max-w-md rounded-xl border border-n-weak bg-white p-5 shadow-xl dark:bg-n-solid-2"
    >
      <div class="mb-4 flex items-center gap-2">
        <span class="i-lucide-clock text-n-blue-11" />
        <h3 class="text-sm font-semibold text-n-slate-12">
          {{ t('CONVERSATION.SCHEDULE_MESSAGE.TITLE') }}
        </h3>
      </div>

      <div class="flex flex-col gap-3">
        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('CONVERSATION.SCHEDULE_MESSAGE.MESSAGE_LABEL') }}
          </label>
          <textarea
            v-model="messageText"
            rows="3"
            class="w-full resize-none rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 placeholder:text-n-slate-9 focus:border-n-brand focus:outline-none"
            :placeholder="
              t('CONVERSATION.SCHEDULE_MESSAGE.MESSAGE_PLACEHOLDER')
            "
          />
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('CONVERSATION.SCHEDULE_MESSAGE.DATE_LABEL') }}
          </label>
          <input
            v-model="scheduledAt"
            type="datetime-local"
            :min="minDateTime"
            class="w-full rounded-lg border border-n-weak bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 focus:border-n-brand focus:outline-none"
          />
        </div>
      </div>

      <div class="mt-4 flex justify-end gap-2">
        <button
          class="rounded-lg px-3 py-1.5 text-sm text-n-slate-11 hover:bg-n-alpha-2"
          @click="$emit('close')"
        >
          {{ t('CONVERSATION.SCHEDULE_MESSAGE.CANCEL') }}
        </button>
        <button
          :disabled="!isValid || isSubmitting"
          class="flex items-center gap-1.5 rounded-lg bg-n-brand px-3 py-1.5 text-sm font-medium text-white disabled:opacity-40"
          @click="handleSchedule"
        >
          <span
            v-if="isSubmitting"
            class="i-lucide-loader-circle animate-spin"
          />
          <span v-else class="i-lucide-clock" />
          {{ t('CONVERSATION.SCHEDULE_MESSAGE.CONFIRM') }}
        </button>
      </div>
    </div>
  </div>
</template>
