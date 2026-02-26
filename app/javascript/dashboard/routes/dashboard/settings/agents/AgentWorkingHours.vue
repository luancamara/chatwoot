<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AgentWorkingHoursAPI from 'dashboard/api/agentWorkingHours';
import BusinessDay from '../inbox/components/BusinessDay.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import {
  timeSlotParse,
  timeSlotTransform,
  defaultTimeSlot,
} from '../inbox/helpers/businessHour';

const props = defineProps({
  userId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const isLoading = ref(false);
const isSaving = ref(false);
const timeSlots = ref([...defaultTimeSlot]);

const dayNames = {
  0: 'Sunday',
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
};

const hasError = computed(() => {
  return timeSlots.value.filter(slot => slot.from && !slot.valid).length > 0;
});

const fetchWorkingHours = async userId => {
  if (!userId) return;
  isLoading.value = true;
  try {
    const { data } = await AgentWorkingHoursAPI.index(userId);
    if (data?.length) {
      timeSlots.value = timeSlotParse(data);
    }
  } catch {
    // Use defaults if not loaded yet
  } finally {
    isLoading.value = false;
  }
};

const onSlotUpdate = (slotIndex, slotData) => {
  timeSlots.value = timeSlots.value.map(item =>
    item.day === slotIndex ? slotData : item
  );
};

const saveWorkingHours = async () => {
  isSaving.value = true;
  try {
    const payload = timeSlotTransform(timeSlots.value).map(slot => ({
      day_of_week: slot.day_of_week,
      open_hour: slot.open_hour,
      open_minutes: slot.open_minutes,
      close_hour: slot.close_hour,
      close_minutes: slot.close_minutes,
      closed_all_day: slot.closed_all_day,
    }));
    await AgentWorkingHoursAPI.update(props.userId, payload);
    useAlert(t('AGENT_MGMT.WORKING_HOURS.API.SUCCESS'));
  } catch {
    useAlert(t('AGENT_MGMT.WORKING_HOURS.API.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

watch(
  () => props.userId,
  newId => fetchWorkingHours(newId)
);

onMounted(() => fetchWorkingHours(props.userId));
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-center justify-between">
      <div>
        <h3 class="text-base font-medium text-n-slate-12">
          {{ t('AGENT_MGMT.WORKING_HOURS.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ t('AGENT_MGMT.WORKING_HOURS.DESCRIPTION') }}
        </p>
      </div>
    </div>

    <div
      v-if="isLoading"
      class="flex items-center gap-2 text-sm text-n-slate-11"
    >
      <span class="i-lucide-loader-circle animate-spin" />
      {{ t('AGENT_MGMT.WORKING_HOURS.LOADING') }}
    </div>

    <form v-else class="flex flex-col" @submit.prevent="saveWorkingHours">
      <div class="w-full overflow-x-auto">
        <table
          class="min-w-full table-auto outline outline-1 -outline-offset-1 outline-n-weak rounded-xl"
        >
          <thead>
            <tr class="border-b border-n-weak">
              <th
                class="py-3 ltr:pl-4 ltr:pr-3 rtl:pl-3 rtl:pr-4 text-start text-heading-3 text-n-slate-12"
              >
                {{ t('INBOX_MGMT.BUSINESS_HOURS.DAY.DAY') }}
              </th>
              <th
                class="py-3 ltr:pr-3 rtl:pl-3 text-start text-heading-3 text-n-slate-12"
              >
                {{ t('INBOX_MGMT.BUSINESS_HOURS.DAY.AVAILABILITY') }}
              </th>
              <th
                class="py-3 ltr:pr-3 rtl:pl-3 text-start text-heading-3 text-n-slate-12"
              >
                {{ t('INBOX_MGMT.BUSINESS_HOURS.DAY.HOURS') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak">
            <BusinessDay
              v-for="timeSlot in timeSlots"
              :key="timeSlot.day"
              :day-name="dayNames[timeSlot.day]"
              :time-slot="timeSlot"
              @update="data => onSlotUpdate(timeSlot.day, data)"
            />
          </tbody>
        </table>
      </div>
      <div class="w-full flex justify-end items-center py-4 mt-2">
        <NextButton
          type="submit"
          :label="t('AGENT_MGMT.WORKING_HOURS.SAVE')"
          :is-loading="isSaving"
          :disabled="hasError"
        />
      </div>
    </form>
  </div>
</template>
