<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'next/textarea/TextArea.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();

const showForm = ref(false);
const newRemindAt = ref('');
const newNotes = ref('');

const reminders = computed(
  () =>
    store.getters['followUpReminders/getByConversationId'](
      props.conversationId
    ) || []
);

const pendingReminders = computed(() =>
  reminders.value.filter(r => r.status === 'pending')
);

const uiFlags = computed(
  () => store.getters['followUpReminders/getUIFlags']
);

const fetchReminders = conversationId => {
  if (!conversationId) return;
  store.dispatch('followUpReminders/fetch', conversationId);
};

const formatDate = dateStr => {
  if (!dateStr) return '';
  return new Intl.DateTimeFormat('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(dateStr));
};

const handleCreate = async () => {
  if (!newRemindAt.value) return;
  try {
    await store.dispatch('followUpReminders/create', {
      conversationId: props.conversationId,
      remind_at: newRemindAt.value,
      notes: newNotes.value,
    });
    useAlert(t('CRM.FOLLOW_UP_REMINDERS.API.CREATE_SUCCESS'));
    showForm.value = false;
    newRemindAt.value = '';
    newNotes.value = '';
  } catch {
    useAlert(t('CRM.FOLLOW_UP_REMINDERS.API.CREATE_ERROR'));
  }
};

const handleDismiss = async reminder => {
  try {
    await store.dispatch('followUpReminders/update', {
      conversationId: props.conversationId,
      reminderId: reminder.id,
      status: 'dismissed',
    });
  } catch {
    useAlert(t('CRM.FOLLOW_UP_REMINDERS.API.DELETE_ERROR'));
  }
};

const handleDelete = async reminder => {
  try {
    await store.dispatch('followUpReminders/delete', {
      conversationId: props.conversationId,
      reminderId: reminder.id,
    });
    useAlert(t('CRM.FOLLOW_UP_REMINDERS.API.DELETE_SUCCESS'));
  } catch {
    useAlert(t('CRM.FOLLOW_UP_REMINDERS.API.DELETE_ERROR'));
  }
};

watch(
  () => props.conversationId,
  newId => fetchReminders(newId)
);

onMounted(() => fetchReminders(props.conversationId));
</script>

<template>
  <div class="py-2">
    <div v-if="uiFlags.isFetching" class="flex items-center gap-2 text-sm text-n-slate-11">
      <span class="i-lucide-loader-circle animate-spin" />
    </div>

    <template v-else>
      <div v-if="pendingReminders.length" class="flex flex-col gap-2">
        <div
          v-for="reminder in pendingReminders"
          :key="reminder.id"
          class="flex items-start gap-2 rounded-lg bg-n-alpha-1 p-2"
        >
          <span class="i-lucide-bell mt-0.5 text-n-slate-11 shrink-0" />
          <div class="flex flex-col gap-0.5 flex-1 min-w-0">
            <span class="text-xs font-medium text-n-slate-12">
              {{ formatDate(reminder.remind_at) }}
            </span>
            <span
              v-if="reminder.notes"
              class="text-xs text-n-slate-11 truncate"
            >
              {{ reminder.notes }}
            </span>
          </div>
          <div class="flex gap-1 shrink-0">
            <Button
              icon="i-lucide-check"
              size="xs"
              ghost
              slate
              @click="handleDismiss(reminder)"
            />
            <Button
              icon="i-lucide-trash-2"
              size="xs"
              ghost
              slate
              @click="handleDelete(reminder)"
            />
          </div>
        </div>
      </div>

      <div
        v-else-if="!showForm"
        class="text-sm text-n-slate-11"
      >
        {{ t('CRM.FOLLOW_UP_REMINDERS.EMPTY') }}
      </div>

      <!-- Add form -->
      <div v-if="showForm" class="flex flex-col gap-2 mt-2">
        <Input
          v-model="newRemindAt"
          type="datetime-local"
          size="sm"
          :placeholder="t('CRM.FOLLOW_UP_REMINDERS.FORM.DUE_AT')"
        />
        <TextArea
          v-model="newNotes"
          class="w-full"
          :placeholder="t('CRM.FOLLOW_UP_REMINDERS.FORM.DESCRIPTION_PLACEHOLDER')"
        />
        <div class="flex gap-2">
          <Button
            :label="t('CRM.FOLLOW_UP_REMINDERS.FORM.SAVE')"
            size="sm"
            color="primary"
            :is-loading="uiFlags.isCreating"
            @click="handleCreate"
          />
          <Button
            :label="t('CRM.FOLLOW_UP_REMINDERS.FORM.CANCEL')"
            size="sm"
            ghost
            slate
            @click="showForm = false"
          />
        </div>
      </div>

      <Button
        v-if="!showForm"
        :label="t('CRM.FOLLOW_UP_REMINDERS.ADD')"
        size="sm"
        ghost
        slate
        icon="i-lucide-plus"
        class="mt-2"
        @click="showForm = true"
      />
    </template>
  </div>
</template>
