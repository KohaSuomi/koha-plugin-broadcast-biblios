const { defineStore } = Pinia;
const { ref, computed } = Vue;
import { useErrorStore } from "./error-store.js";

export const useActiveStore = defineStore("active", {
  state: () => {
    return {
      record: ref({}),
      saved: ref(false),
      loader: ref(true),
    };
  },
  actions: {
    async get(biblio_id) {
      try {
        const response = await axios.get("/api/v1/contrib/kohasuomi/broadcast/biblios/active/" + biblio_id);
        this.record = response.data;
        this.saved = true;
        this.loader = false;
      } catch (error) {
        this.loader = false;
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async save(biblio_id, interface_name) {
      try {
        const response = await axios.post("/api/v1/contrib/kohasuomi/broadcast/biblios/active/" + biblio_id, {
          broadcast_interface: interface_name,
        });
        this.saved = true;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    }
  },
});
