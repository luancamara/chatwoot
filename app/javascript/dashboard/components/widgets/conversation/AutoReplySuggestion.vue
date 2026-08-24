<script setup>
import CaptainLoader from 'dashboard/components/widgets/conversation/copilot/CaptainLoader.vue';
import Icon from 'next/icon/Icon.vue';

defineProps({
  isGenerating: {
    type: Boolean,
    default: false,
  },
  suggestion: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['accept', 'dismiss']);
</script>

<template>
  <div
    class="mx-3 mb-3 overflow-hidden rounded-xl border border-n-iris-5 bg-n-iris-2/60 shadow-sm"
    aria-live="polite"
  >
    <div v-if="isGenerating" class="flex items-center gap-2 px-3 py-2.5">
      <CaptainLoader class="size-4 shrink-0 text-n-iris-10" />
      <span class="text-sm text-n-iris-11">
        {{ $t('CONVERSATION.REPLYBOX.AUTO_REPLY_SUGGESTION.LOADING') }}
      </span>
    </div>
    <template v-else-if="suggestion">
      <div class="flex items-center justify-between gap-3 px-3 pt-2.5">
        <div
          class="flex items-center gap-1.5 text-xs font-medium text-n-iris-11"
        >
          <Icon icon="i-woot-captain" class="size-4" />
          <span>
            {{ $t('CONVERSATION.REPLYBOX.AUTO_REPLY_SUGGESTION.TITLE') }}
          </span>
        </div>
        <button
          type="button"
          class="grid size-6 place-items-center rounded-md text-n-slate-10 transition-colors hover:bg-n-iris-4 hover:text-n-slate-12 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-iris-8"
          :aria-label="
            $t('CONVERSATION.REPLYBOX.AUTO_REPLY_SUGGESTION.DISMISS')
          "
          @click="emit('dismiss')"
        >
          <Icon icon="i-lucide-x" class="size-3.5" />
        </button>
      </div>
      <button
        type="button"
        class="group w-full px-3 pb-3 pt-1.5 text-left focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-n-iris-8"
        @click="emit('accept')"
      >
        <span
          class="block max-h-40 overflow-y-auto whitespace-pre-wrap text-sm leading-5 text-n-slate-12"
        >
          {{ suggestion }}
        </span>
        <span
          class="mt-2 flex items-center gap-1.5 text-xs text-n-slate-10 transition-colors group-hover:text-n-iris-11"
        >
          {{ $t('CONVERSATION.REPLYBOX.AUTO_REPLY_SUGGESTION.USE_HINT') }}
          <kbd
            class="rounded border border-n-weak bg-n-solid-1 px-1.5 py-0.5 font-sans text-[10px] text-n-slate-11"
          >
            {{ $t('CONVERSATION.REPLYBOX.AUTO_REPLY_SUGGESTION.SHORTCUT') }}
          </kbd>
        </span>
      </button>
    </template>
  </div>
</template>
