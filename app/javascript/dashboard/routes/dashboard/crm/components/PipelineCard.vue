<script setup>
import { computed, ref, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { formatDistanceToNow } from 'date-fns';

const props = defineProps({
  conversation: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['open', 'updateValue']);

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

const rawValue = computed(
  () => props.conversation.custom_attributes?.crm_estimated_value
);

const estimatedValue = computed(() => {
  if (!rawValue.value) return '';
  return `R$ ${Number(rawValue.value).toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`;
});

const timeInStage = computed(() => {
  const updatedAt = props.conversation.custom_attributes?.crm_stage_changed_at;
  if (!updatedAt) return '';
  return formatDistanceToNow(new Date(updatedAt), { addSuffix: false });
});

const displayId = computed(() => `#${props.conversation.display_id}`);

const isEditingValue = ref(false);
const draftValue = ref('');
const valueInput = ref(null);

const startEditValue = async () => {
  draftValue.value = rawValue.value ?? '';
  isEditingValue.value = true;
  await nextTick();
  valueInput.value?.$el?.querySelector('input')?.focus();
};

const saveValue = () => {
  if (!isEditingValue.value) return;
  isEditingValue.value = false;
  const parsed = parseFloat(String(draftValue.value).replace(',', '.'));
  const next = Number.isNaN(parsed) ? null : parsed;
  if (next !== (rawValue.value ?? null)) {
    emit('updateValue', next);
  }
};
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
      <div class="flex items-center gap-1.5 flex-shrink-0">
        <span class="text-xs text-n-slate-10">
          {{ displayId }}
        </span>
        <button
          type="button"
          class="flex items-center justify-center size-5 rounded text-n-slate-10 hover:text-n-slate-12 hover:bg-n-solid-3"
          :title="t('CRM.PIPELINE.OPEN_CONVERSATION')"
          @click.stop="emit('open')"
          @mousedown.stop
        >
          <span class="i-lucide-external-link size-3.5" />
        </button>
      </div>
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
      <div class="flex items-center gap-2" @mousedown.stop @click.stop>
        <Input
          v-if="isEditingValue"
          ref="valueInput"
          v-model="draftValue"
          type="number"
          size="sm"
          class="w-24"
          :placeholder="t('CRM.PIPELINE.VALUE_PLACEHOLDER')"
          @keyup.enter="saveValue"
          @blur="saveValue"
        />
        <button
          v-else
          type="button"
          class="text-xs font-medium rounded px-1 py-0.5 hover:bg-n-solid-3"
          :class="estimatedValue ? 'text-n-teal-11' : 'text-n-slate-10'"
          @click="startEditValue"
        >
          {{ estimatedValue || t('CRM.PIPELINE.ADD_VALUE') }}
        </button>
        <span v-if="timeInStage" class="text-xs text-n-slate-10">
          {{ timeInStage }}
        </span>
      </div>
    </div>
  </div>
</template>
