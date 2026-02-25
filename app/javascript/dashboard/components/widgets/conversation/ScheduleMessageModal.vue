<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
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
const isSubmitting = ref(false);

const minDateTime = computed(() => {
  const now = new Date();
  now.setMinutes(now.getMinutes() + 5);
  return now.toISOString().slice(0, 16);
});

const previewContent = computed(() => {
  const content = props.messageContent || '';
  return content.length > 200 ? `${content.slice(0, 200)}...` : content;
});

const isValid = computed(() => {
  return scheduledAt.value && props.messageContent?.trim();
});

const handleSchedule = async () => {
  if (!isValid.value || isSubmitting.value) return;

  try {
    isSubmitting.value = true;
    await ScheduledMessagesAPI.create(props.conversationId, {
      content: props.messageContent,
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
    class="fixed inset-0 z-50 flex items-center justify-center bg-n-alpha-3"
    @click.self="$emit('close')"
  >
    <div
      class="w-full max-w-md rounded-xl border border-n-weak bg-n-solid-2 p-6 shadow-lg"
    >
      <h3 class="mb-4 text-base font-semibold text-n-slate-12">
        {{ t('CONVERSATION.SCHEDULE_MESSAGE.TITLE') }}
      </h3>

      <div
        v-if="previewContent"
        class="mb-4 rounded-lg bg-n-alpha-1 p-3 text-sm text-n-slate-11"
      >
        <span class="mb-1 block text-xs font-medium text-n-slate-10">
          {{ t('CONVERSATION.SCHEDULE_MESSAGE.PREVIEW') }}
        </span>
        {{ previewContent }}
      </div>

      <div class="mb-4 flex flex-col gap-1">
        <label class="text-xs font-medium text-n-slate-11">
          {{ t('CONVERSATION.SCHEDULE_MESSAGE.DATE_LABEL') }}
        </label>
        <Input
          v-model="scheduledAt"
          type="datetime-local"
          :min="minDateTime"
          size="sm"
        />
      </div>

      <div class="flex justify-end gap-2">
        <Button
          :label="t('CONVERSATION.SCHEDULE_MESSAGE.CANCEL')"
          size="sm"
          ghost
          slate
          @click="$emit('close')"
        />
        <Button
          :label="t('CONVERSATION.SCHEDULE_MESSAGE.CONFIRM')"
          size="sm"
          color="primary"
          icon="i-lucide-clock"
          :is-loading="isSubmitting"
          :disabled="!isValid"
          @click="handleSchedule"
        />
      </div>
    </div>
  </div>
</template>
