const { defineStore } = Pinia;
const { ref, computed } = Vue;
import { useErrorStore } from "./error-store.js";

export const useRecordStore = defineStore("record", {
  state: () => {
    return {
      marcjson: ref({}),
      identifiers: ref([]),
      remotemarcjson: ref({}),
      saved: ref(false),
    };
  },
  actions: {
    async getLocal(biblio_id) {
      try {
        const response = await axios.get(`/api/v1/contrib/kohasuomi/broadcast/biblios/${biblio_id}`, { headers: { 'Accept': 'application/marc-in-json' } });
        this.marcjson = response.data.biblio.marcjson;
        this.identifiers = response.data.biblio.identifiers;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async search(biblio_id, interface_name) {
      try {
        const response = await axios.post(`/api/v1/contrib/kohasuomi/broadcast/biblios/${biblio_id}/search`, { interface_name: interface_name, identifiers: this.identifiers });
        this.remotemarcjson = response.data.marcjson;
        return response;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async import(biblio_id) {
      try {
        const marcjson = this.remotemarcjson;
        const response = await axios.post(`/api/v1/contrib/kohasuomi/broadcast/biblios/${biblio_id}/import`, { marcjson: marcjson });
        this.saved = true;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async export(biblio_id, patron_id, interface_name) {
      try {
        const marcjson = this.marcjson;
        const response = await axios.post(`/api/v1/contrib/kohasuomi/broadcast/biblios/${biblio_id}/export`, { marcjson: marcjson, patron_id: patron_id, interface_name: interface_name});
        this.saved = true;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    }
  },
});
