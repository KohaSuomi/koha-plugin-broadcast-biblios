const { defineStore } = Pinia;
const { ref, computed } = Vue;
import { useErrorStore } from "./error-store.js";

export const useRecordStore = defineStore("record", {
  state: () => {
    return {
      marcjson: ref({}),
      componentparts: ref([]),
      identifiers: ref([]),
      remotemarcjson: ref({}),
      remotecomponentparts: ref([]),
      saved: ref(false),
    };
  },
  actions: {
    async getLocal(biblio_id) {
      try {
        const response = await axios.get(`/api/v1/contrib/kohasuomi/broadcast/biblios/${biblio_id}`, { headers: { 'Accept': 'application/marc-in-json' } });
        this.marcjson = response.data.marcjson;
        this.componentparts = response.data.componentparts;
        this.identifiers = response.data.identifiers;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async search(biblio_id, interface_name) {
      try {
        const response = await axios.post(`/api/v1/contrib/kohasuomi/broadcast/biblios/${biblio_id}/search`, { interface_name: interface_name, identifiers: this.identifiers });
        this.remotemarcjson = response.data.marcjson;
        this.remotecomponentparts = response.data.componentparts;
        return response;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async import(biblio_id, patron_id, interface_name, remote_id) {
      try {
        const response = await axios.post(`/api/v1/contrib/kohasuomi/broadcast/biblios/${biblio_id}/import`, { marcjson: this.remotemarcjson, componentparts: this.remotecomponentparts, interface_name: interface_name, patron_id: patron_id, remote_id: remote_id});
        this.saved = true;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async export(remote_id, patron_id, interface_name) {
      try {
        const marcjson = this.marcjson;
        const response = await axios.post(`/api/v1/contrib/kohasuomi/broadcast/biblios/export`, { marcjson: marcjson, patron_id: patron_id, interface_name: interface_name, remote_id: remote_id});
        this.saved = true;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    }
  },
});
