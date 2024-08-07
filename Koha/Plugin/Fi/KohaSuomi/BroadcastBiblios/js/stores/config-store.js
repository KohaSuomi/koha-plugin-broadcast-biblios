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
  getters: {
    onDropdown() {
      return this.interfaces.filter((i) => i.onDropdown === true);
    },
    activationInterface() {
      const interfaces = this.interfaces.filter((i) => i.activationInterface === true);
      return interfaces.length > 0 ? interfaces[0].name : "";
    }
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
    interfaceType(interface_name) {
      return this.interfaces.find((i) => i.name === interface_name).type;
    }
  },
});
