const { defineStore } = Pinia;
const { ref, computed } = Vue;
import { useErrorStore } from "./error-store.js";

export const useRecordStore = defineStore("record", {
  state: () => {
    return {
      localRecord: ref({}),
      remoteRecord: ref({}),
      saved: ref(false),
    };
  },
  actions: {
    async search() {
      try {
        const response = await axios.get("/api/v1/contrib/kohasuomi/broadcast/config");
        this.interfaces = response.data.interfaces;
        this.notifyfields = response.data.notifyfields;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
  },
});
