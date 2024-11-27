const { defineStore } = Pinia;
const { ref, computed } = Vue;
import { useErrorStore } from "./error-store.js";

export const useUserStore = defineStore("user", {
  state: () => ({
    user: ref({}),
    list: ref([]),
    saved: ref(false),
  }),
  actions: {
    async fetch() {
      try {
        const response = await axios.get("/api/v1/contrib/kohasuomi/broadcast/users");
        let users = response.data;
        users = users.sort((a, b) => a.username.localeCompare(b.username));
        this.list = users;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async get(id) {
      try {
        const response = await axios.get("/api/v1/contrib/kohasuomi/broadcast/users/" + id);
        this.user = response.data;
        return  this.user;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async save() {
      try {
        const response = await axios.post("/api/v1/contrib/kohasuomi/broadcast/users", this.user);
        this.user = {};
        this.saved = true;
        this.fetch();
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async update() {
      try {
        const response = await axios.put("/api/v1/contrib/kohasuomi/broadcast/users/" + this.user.id, this.user);
        this.user = {};
        this.saved = true;
        this.fetch();
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async delete() {
      try {
        const response = await axios.delete("/api/v1/contrib/kohasuomi/broadcast/users/" + this.user.id);
        this.user = {};
        this.fetch();
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    }
  },
});
