const { defineStore } = Pinia;
const { ref, computed } = Vue;
import { useErrorStore } from "./error-store.js";

export const useQueueStore = defineStore("queue", {
  state: () => {
    return {
      list: ref([]),
    };
  },
  actions: {
    async fetch(biblio_id, status, page, limit) {
      try {
        const response = await axios.get("/api/v1/contrib/kohasuomi/broadcast/queue", {
          params: { status: status, page: page, limit: limit, biblio_id: biblio_id },
        });
        this.list = response.data.results;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    }
  },
});
