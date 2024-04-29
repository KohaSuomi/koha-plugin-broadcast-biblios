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
    async search(biblio_id, interface_name, patron_id) {
      try {
        const response = await axios.post(`/api/v1/contrib/kohasuomi/broadcast/biblios/${biblio_id}/search`, { interface_name: interface_name, identifiers: this.identifiers, patron_id: patron_id});
        this.remotemarcjson = response.data.marcjson;
        this.remotecomponentparts = response.data.componentparts;
        this.saved = false;
        return response;
      } catch (error) {
        const errorStore = useErrorStore();
        if (error.response && error.response.data.error != 'Not Found') {
          errorStore.setError(error);
        }
      }
    },
    async transfer(biblio_id, patron_id, interface_name, remote_id, type) {
      try {
        const marcjson = type == 'import' ? this.remotemarcjson : this.marcjson;
        const componentparts = type == 'import' ? this.remotecomponentparts : this.componentparts;
        const response = await axios.post(`/api/v1/contrib/kohasuomi/broadcast/biblios/${biblio_id}/transfer`, { marcjson: marcjson, componentparts: componentparts, interface_name: interface_name, patron_id: patron_id, remote_id: remote_id, type: type });
        this.saved = true;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    },
    async transferComponentPart(biblio_id, patron_id, interface_name, type, marcjson) {
      try {
        const response = await axios.post(`/api/v1/contrib/kohasuomi/broadcast/biblios/${biblio_id}/transfer`, { interface_name: interface_name, patron_id: patron_id, type: type, marcjson: marcjson});
        return response;
      } catch (error) {
        const errorStore = useErrorStore();
        errorStore.setError(error);
      }
    }
  },
});
