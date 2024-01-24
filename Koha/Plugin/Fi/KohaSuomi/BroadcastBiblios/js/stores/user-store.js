const { defineStore } = Pinia;
const { ref, computed } = Vue;
import { useErrorStore } from "./error-store.js";

export const useUserStore = defineStore("user", {
  state: () => ({
    user: {},
    list: [],
  }),
  actions: {
    async fetch() {
      try {
        const response = await axios.get("/api/v1/contrib/kohasuomi/broadcast/users");
        this.list = response.data;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async save() {
      try {
        const response = await axios.post("/api/v1/contrib/kohasuomi/broadcast/users", this.user);
        this.user = {};
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
  },
});
