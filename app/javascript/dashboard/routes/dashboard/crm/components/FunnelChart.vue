<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  stages: {
    type: Array,
    default: () => [],
  },
  conversionRates: {
    type: Array,
    default: () => [],
  },
});

const { t } = useI18n();

const maxCount = computed(() => {
  if (!props.stages.length) return 1;
  return Math.max(...props.stages.map(s => s.count), 1);
});

const conversionRateMap = computed(() => {
  const map = {};
  props.conversionRates.forEach(cr => {
    map[cr.from] = cr.rate;
  });
  return map;
});
</script>

<template>
  <div class="flex flex-col gap-1">
    <div
      v-for="stage in stages"
      :key="stage.stage"
      class="flex flex-col gap-1"
    >
      <div class="flex items-center gap-3">
        <span class="w-28 text-sm font-medium text-n-slate-12 shrink-0 truncate">
          {{ stage.stage }}
        </span>
        <div class="flex-1 h-8 bg-n-alpha-1 rounded-md overflow-hidden">
          <div
            class="h-full bg-n-brand rounded-md flex items-center px-2 transition-all duration-300"
            :style="{ width: `${Math.max((stage.count / maxCount) * 100, 2)}%` }"
          >
            <span class="text-xs font-medium text-white whitespace-nowrap">
              {{ stage.count }}
            </span>
          </div>
        </div>
      </div>
      <div
        v-if="conversionRateMap[stage.stage] !== undefined"
        class="flex items-center gap-3 ml-28 pl-3"
      >
        <span class="i-lucide-arrow-down size-3 text-n-slate-10" />
        <span class="text-xs text-n-slate-10">
          {{ conversionRateMap[stage.stage] }}%
          {{ t('CRM.FUNNEL.CONVERSION_RATE').toLowerCase() }}
        </span>
      </div>
    </div>
  </div>
</template>
