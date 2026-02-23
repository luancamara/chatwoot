<script setup>
defineProps({
  label: {
    type: String,
    required: true,
  },
  value: {
    type: [String, Number],
    required: true,
  },
});
</script>

<template>
  <div class="flex flex-col gap-1 p-4 rounded-lg bg-n-solid-2 outline outline-1 outline-n-container">
    <span class="text-xs font-medium text-n-slate-11">{{ label }}</span>
    <span class="text-xl font-semibold text-n-slate-12">{{ value }}</span>
  </div>
</template>
