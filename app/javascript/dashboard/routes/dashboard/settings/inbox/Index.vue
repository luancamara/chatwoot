<script setup>
import { computed, onActivated, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Avatar from 'next/avatar/Avatar.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import {
  useMapGetter,
  useStoreGetters,
  useStore,
} from 'dashboard/composables/store';
import ChannelName from './components/ChannelName.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import { getInboxIdentifier, searchInboxes } from 'dashboard/helper/inbox';

const IDENTIFIER_SEPARATOR = '·';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();
const { isAdmin } = useAdmin();

const showDeletePopup = ref(false);
const selectedInbox = ref({});
const searchQuery = ref('');
const activityFilter = ref('all');
const updatingInboxId = ref(null);

const activityOptions = computed(() => [
  { value: 'all', label: t('INBOX_MGMT.ARCHIVE.FILTER.ALL') },
  { value: 'active', label: t('INBOX_MGMT.ARCHIVE.FILTER.ACTIVE') },
  { value: 'inactive', label: t('INBOX_MGMT.ARCHIVE.FILTER.INACTIVE') },
]);

const inboxes = useMapGetter('inboxes/getInboxes');

onActivated(() => {
  store.dispatch('inboxes/get');
});

const inboxesList = computed(() => {
  return inboxes.value
    ?.map(inbox => ({
      ...inbox,
      channel_identifier: getInboxIdentifier(inbox),
    }))
    .sort((a, b) => a.name.localeCompare(b.name));
});

const filteredInboxesList = computed(() => {
  const query = searchQuery.value.trim();
  const matchingInboxes = query
    ? searchInboxes(inboxesList.value, query)
    : inboxesList.value;
  if (activityFilter.value === 'all') return matchingInboxes;
  return matchingInboxes.filter(inbox =>
    activityFilter.value === 'inactive' ? inbox.archived : !inbox.archived
  );
});

const uiFlags = computed(() => getters['inboxes/getUIFlags'].value);

const deleteConfirmText = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.YES')} ${selectedInbox.value.name}`
);

const deleteRejectText = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.NO')} ${selectedInbox.value.name}`
);

const confirmDeleteMessage = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.MESSAGE')} ${selectedInbox.value.name}?`
);
const confirmPlaceHolderText = computed(
  () =>
    `${t('INBOX_MGMT.DELETE.CONFIRM.PLACE_HOLDER', {
      inboxName: selectedInbox.value.name,
    })}`
);

const deleteInbox = async ({ id }) => {
  try {
    await store.dispatch('inboxes/delete', id);
    useAlert(t('INBOX_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.DELETE.API.ERROR_MESSAGE'));
  }
};
const closeDelete = () => {
  showDeletePopup.value = false;
  selectedInbox.value = {};
};

const confirmDeletion = () => {
  deleteInbox(selectedInbox.value);
  closeDelete();
};
const openDelete = inbox => {
  showDeletePopup.value = true;
  selectedInbox.value = inbox;
};

const toggleArchived = async inbox => {
  const archived = !inbox.archived;
  updatingInboxId.value = inbox.id;
  try {
    await store.dispatch('inboxes/updateInbox', {
      id: inbox.id,
      formData: false,
      archived,
    });
    useAlert(
      archived
        ? t('INBOX_MGMT.ARCHIVE.DEACTIVATED')
        : t('INBOX_MGMT.ARCHIVE.REACTIVATED')
    );
  } catch {
    useAlert(t('INBOX_MGMT.ARCHIVE.ERROR'));
  } finally {
    updatingInboxId.value = null;
  }
};
</script>

<template>
  <SettingsLayout
    :no-records-found="!inboxesList.length"
    :no-records-message="$t('INBOX_MGMT.LIST.404')"
    :is-loading="uiFlags.isFetching"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('INBOX_MGMT.HEADER')"
        :description="$t('INBOX_MGMT.DESCRIPTION')"
        :link-text="$t('INBOX_MGMT.LEARN_MORE')"
        :search-placeholder="$t('INBOX_MGMT.SEARCH_PLACEHOLDER')"
        feature-name="inboxes"
      >
        <template v-if="inboxesList?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('INBOX_MGMT.COUNT', { n: inboxesList.length }) }}
          </span>
        </template>
        <template #actions>
          <Select
            v-model="activityFilter"
            :options="activityOptions"
            :aria-label="$t('INBOX_MGMT.ARCHIVE.FILTER_LABEL')"
          />
          <router-link v-if="isAdmin" :to="{ name: 'settings_inbox_new' }">
            <Button :label="$t('SETTINGS.INBOXES.NEW_INBOX')" size="sm" />
          </router-link>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <p class="text-body-main text-n-slate-11 pb-4">
        {{ $t('INBOX_MGMT.ARCHIVE.HELP') }}
      </p>
      <span
        v-if="!filteredInboxesList.length"
        class="flex-1 flex items-center justify-center py-20 text-center text-body-main !text-base text-n-slate-11"
      >
        {{
          searchQuery
            ? $t('INBOX_MGMT.NO_RESULTS')
            : $t('INBOX_MGMT.ARCHIVE.EMPTY_FILTER')
        }}
      </span>
      <div v-else class="divide-y divide-n-weak border-t border-n-weak">
        <div
          v-for="inbox in filteredInboxesList"
          :key="inbox.id"
          class="flex justify-between flex-col sm:flex-row items-start gap-4 py-4"
        >
          <div class="flex items-center gap-4 min-w-0 flex-1">
            <div
              v-if="inbox.avatar_url"
              class="bg-n-alpha-3 rounded-xl size-10 ring ring-n-solid-1 border border-n-strong shadow-sm grid place-items-center"
            >
              <Avatar
                :src="inbox.avatar_url"
                :name="inbox.name"
                :size="24"
                rounded-full
              />
            </div>
            <div
              v-else
              class="size-10 justify-center bg-n-alpha-3 rounded-xl ring ring-n-solid-1 border border-n-strong shadow-sm grid place-items-center"
            >
              <ChannelIcon class="size-6 text-n-slate-10" :inbox="inbox" />
            </div>
            <div class="flex flex-col items-start gap-1 min-w-0">
              <div class="flex items-center gap-2 min-w-0 max-w-full">
                <span
                  :title="inbox.name"
                  class="block text-heading-3 text-n-slate-12 capitalize truncate min-w-0"
                >
                  {{ inbox.name }}
                </span>
                <span
                  v-if="inbox.archived"
                  class="shrink-0 rounded-md bg-n-slate-3 px-2 py-1 text-xs text-n-slate-11"
                >
                  {{ $t('INBOX_MGMT.ARCHIVE.INACTIVE') }}
                </span>
              </div>
              <div
                class="flex items-center gap-1 min-w-0 max-w-full text-body-main text-n-slate-11"
              >
                <ChannelName
                  :channel-type="inbox.channel_type"
                  :medium="inbox.medium"
                  :voice-enabled="inbox.voice_enabled"
                  class="shrink-0"
                />
                <template v-if="inbox.channel_identifier">
                  <span aria-hidden="true">{{ IDENTIFIER_SEPARATOR }}</span>
                  <bdi
                    dir="auto"
                    :title="inbox.channel_identifier"
                    class="truncate"
                    data-test-id="channel-identifier"
                  >
                    {{ inbox.channel_identifier }}
                  </bdi>
                </template>
              </div>
            </div>
          </div>
          <div class="flex gap-3 justify-end shrink-0">
            <Button
              v-if="isAdmin"
              :label="
                inbox.archived
                  ? $t('INBOX_MGMT.ARCHIVE.REACTIVATE')
                  : $t('INBOX_MGMT.ARCHIVE.DEACTIVATE')
              "
              :aria-label="
                inbox.archived
                  ? $t('INBOX_MGMT.ARCHIVE.REACTIVATE_NAMED', {
                      inboxName: inbox.name,
                    })
                  : $t('INBOX_MGMT.ARCHIVE.DEACTIVATE_NAMED', {
                      inboxName: inbox.name,
                    })
              "
              :icon="
                inbox.archived ? 'i-lucide-archive-restore' : 'i-lucide-archive'
              "
              :is-loading="updatingInboxId === inbox.id"
              :disabled="updatingInboxId !== null"
              :data-test-id="`inbox-archive-${inbox.id}`"
              variant="faded"
              color="slate"
              size="sm"
              @click="toggleArchived(inbox)"
            />
            <router-link
              :to="{
                name: 'settings_inbox_show',
                params: { inboxId: inbox.id },
              }"
            >
              <Button
                v-if="isAdmin"
                v-tooltip.top="$t('INBOX_MGMT.SETTINGS')"
                icon="i-woot-settings"
                slate
                sm
              />
            </router-link>
            <Button
              v-if="isAdmin"
              v-tooltip.top="$t('INBOX_MGMT.DELETE.BUTTON_TEXT')"
              icon="i-woot-bin"
              slate
              sm
              class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
              @click="openDelete(inbox)"
            />
          </div>
        </div>
      </div>
    </template>

    <woot-confirm-delete-modal
      v-if="showDeletePopup"
      v-model:show="showDeletePopup"
      :title="$t('INBOX_MGMT.DELETE.CONFIRM.TITLE')"
      :message="confirmDeleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
      :confirm-value="selectedInbox.name"
      :confirm-place-holder-text="confirmPlaceHolderText"
      @on-confirm="confirmDeletion"
      @on-close="closeDelete"
    />
  </SettingsLayout>
</template>
