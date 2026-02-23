<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { formatDistanceToNow } from 'date-fns';

const props = defineProps({
  conversation: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const contactName = computed(
  () =>
    props.conversation.meta?.sender?.name ||
    t('CRM.PIPELINE.UNKNOWN_CONTACT')
);

const contactAvatar = computed(
  () => props.conversation.meta?.sender?.thumbnail || ''
);

const assigneeName = computed(
  () => props.conversation.meta?.assignee?.name || ''
);

const assigneeAvatar = computed(
  () => props.conversation.meta?.assignee?.thumbnail || ''
);

const lastMessagePreview = computed(() => {
  const content = props.conversation.last_non_activity_message?.content;
  if (!content) return '';
  return content.length > 60 ? `${content.slice(0, 60)}...` : content;
});

const estimatedValue = computed(() => {
  const value =
    props.conversation.custom_attributes?.crm_estimated_value;
  if (!value) return '';
  return `R$ ${Number(value).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`;
});

const timeInStage = computed(() => {
  const updatedAt = props.conversation.custom_attributes?.crm_stage_changed_at;
  if (!updatedAt) return '';
  return formatDistanceToNow(new Date(updatedAt), { addSuffix: false });
});

const displayId = computed(() => `#${props.conversation.display_id}`);
</script>

<template>
  <div
    class="flex flex-col gap-2 p-3 rounded-lg bg-n-solid-1 outline outline-1 outline-n-container cursor-grab active:cursor-grabbing hover:outline-n-slate-7 transition-colors"
  >
    <div class="flex items-center justify-between gap-2">
      <div class="flex items-center gap-2 min-w-0">
        <Avatar :name="contactName" :src="contactAvatar" :size="24" />
        <span class="text-sm font-medium text-n-slate-12 truncate">
          {{ contactName }}
        </span>
      </div>
      <span class="text-xs text-n-slate-10 flex-shrink-0">
        {{ displayId }}
      </span>
    </div>

    <p
      v-if="lastMessagePreview"
      class="text-xs text-n-slate-11 line-clamp-2"
    >
      {{ lastMessagePreview }}
    </p>

    <div class="flex items-center justify-between gap-2">
      <div class="flex items-center gap-1">
        <Avatar
          v-if="assigneeName"
          :name="assigneeName"
          :src="assigneeAvatar"
          :size="18"
        />
        <span v-if="assigneeName" class="text-xs text-n-slate-10 truncate max-w-[80px]">
          {{ assigneeName }}
        </span>
      </div>
      <div class="flex items-center gap-2">
        <span
          v-if="estimatedValue"
          class="text-xs font-medium text-n-teal-11"
        >
          {{ estimatedValue }}
        </span>
        <span v-if="timeInStage" class="text-xs text-n-slate-10">
          {{ timeInStage }}
        </span>
      </div>
    </div>
  </div>
</template>
