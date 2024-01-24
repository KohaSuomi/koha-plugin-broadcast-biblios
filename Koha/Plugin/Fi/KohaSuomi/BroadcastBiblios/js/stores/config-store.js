const { defineStore } = Pinia;
const { ref, computed } = Vue;
import { useErrorStore } from "./error-store.js";

export const useConfigStore = defineStore("config", {
  state: () => {
    return {
      interfaces: ref([]),
      notifyfields: ref(""),
      saved: ref(false),
    };
  },
  actions: {
    async fetch() {
      try {
        const response = await axios.get("/api/v1/contrib/kohasuomi/broadcast/config");
        this.interfaces = response.data.interfaces;
        this.notifyfields = response.data.notifyfields;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async save() {
      try {
        const response = await axios.post("/api/v1/contrib/kohasuomi/broadcast/config", {interfaces: this.interfaces, notifyfields: this.notifyfields});
        this.saved = true;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
  },
});
