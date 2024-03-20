import { useConfigStore } from "../stores/config-store.js";
import { useErrorStore } from "../stores/error-store.js";
import { useUserStore } from "../stores/user-store.js";

export default {
  setup() {
    const configStore = useConfigStore();
    const errorStore = useErrorStore();
    const userStore = useUserStore();
    return {
      config: configStore,
      errors: errorStore,
      users: userStore,
    };
  },
  data() {
    return {
      showInterface: false,
      selectedInterface: {},
      interfaceName: "",
      interfaceTypes: [
        { id: "import", name: "Valutus" },
        { id: "export", name: "Vienti" },
      ],
    };
  },
  created() {
    this.config.fetch();
    this.users.fetch();
  },
  methods: {
    async save() {
      this.config.saved = false;
      let newInterface = true;
      for (let i = 0; i < this.config.interfaces.length; i++) {
        if (this.config.interfaces[i].name === this.selectedInterface.name) {
          this.config.interfaces[i] = this.selectedInterface;
          newInterface = false;
        }
      }
      if (
        newInterface &&
        this.selectedInterface.name !== "" &&
        Object.keys(this.selectedInterface).length > 0
      ) {
        this.config.interfaces.push(this.selectedInterface);
      }
      const valid = await this.isValid();
      if (valid) {
        this.config.save();
      }
    },
    addInterface() {
      this.selectedInterface = {};
      this.showInterface = true;
      this.interfaceName = "";
    },
    removeInterface() {
      this.config.saved = false;
      for (let i = 0; i < this.config.interfaces.length; i++) {
        if (this.config.interfaces[i].name === this.interfaceName) {
          this.config.interfaces.splice(i, 1);
          this.selectedInterface = {};
          this.showInterface = false;
          this.interfaceName = "";
        }
      }
      this.config.save();
    },
    selectedInterfaceChanged(event) {
      this.selectedInterface = this.config.interfaces.find(
        (i) => i.name === event.target.value
      );
      if (!this.interfaceName) {
        this.selectedInterface = {};
        this.showInterface = false;
      } else {
        this.interfaceName = event.target.value;
        this.showInterface = true;
      }
    },
    async isValid() {
      this.errors.clearError();
      let valid = true;
      if (!this.selectedInterface.name) {
        this.errors.setError("Nimi on pakollinen");
        valid = false;
      }
      if (!this.selectedInterface.type) {
        this.errors.setError("Tyyppi on pakollinen");
        valid = false;
      }
      if (
        (this.selectedInterface.restUrl === undefined && this.selectedInterface.restUrl === "") ||
        (this.selectedInterface.sruUrl === undefined && this.selectedInterface.sruUrl === "")
      ) {
        this.errors.setError("REST URL tai SRU URL on pakollinen");
        valid = false;
      }
      if (
        this.selectedInterface.restUrl &&
        !this.validateHttpUrl(this.selectedInterface.restUrl)
      ) {
        this.errors.setError("REST URL ei ole validi");
        valid = false;
      }
      if (
        this.selectedInterface.sruUrl &&
        !this.validateHttpUrl(this.selectedInterface.sruUrl)
      ) {
        this.errors.setError("SRU URL ei ole validi");
        valid = false;
      }
      return valid;
    },
    validateHttpUrl(url) {
      if (!url) {
        return false;
      }
      const pattern = new RegExp(
        "^(https?:\\/\\/)?" +
          // protocol
          "((([a-z\\d]([a-z\\d-]*[a-z\\d])*)\\.?)+[a-z]{2,}|" +
          // domain name
          "((\\d{1,3}\\.){3}\\d{1,3}))" +
          // OR ip (v4) address
          "(\\:\\d+)?(\\/[-a-z\\d%_.~+]*)*" +
          // port and path
          "(\\?[;&a-z\\d%_.~+=-]*)?" +
          // query string
          "(\\#[-a-z\\d_]*)?$",
        "i"
      );
      return pattern.test(url);
    },
  },
  template: `
    <div v-if="errors.errors.length > 0" class="alert alert-danger" role="alert">
        <div v-for="error in errors.errors">{{ error }}</div>
    </div>
    <div v-if="config.saved" class="alert alert-success" role="alert">
        Asetukset tallennettu
    </div>
    <form>
    <div class="form-group">
      <label for="name" class="col-form-label">Ilmoita kentistä (erota pilkulla):</label>
      <input type="text" class="form-control" id="notifyfields" v-model="config.notifyfields">
    </div>
    <hr/>
        <div class="form-group row">
            <div class="col-9">
                <select class="form-control" id="interfaces" @change="selectedInterfaceChanged($event)" v-model="interfaceName">
                    <option selected value="">Valitse siirtorajapinta</option>
                    <option v-for="interface in config.interfaces" :value="interface.name">{{ interface.name }}</option>
                </select>
            </div>
            <div class="col-3">
                <button type="button" class="btn btn-success mr-2" @click="addInterface()">Uusi</button>
                <button type="button" :class="interfaceName ? 'btn-danger' : 'btn-grey'" class="btn" @click="removeInterface()" :disabled="!interfaceName">Poista</button>
            </div>
        </div>
        <hr/>
        <div v-show="showInterface">
            <h5>{{interfaceName}}-rajapinnan tiedot</h5>
            <hr>
            <div class="form-group">
                <label for="name" class="col-form-label">Nimi</label>
                <input type="text" class="form-control" id="name" v-model="selectedInterface.name">
            </div>
            <div class="form-group">
                <label for="type" class="col-form-label">Tyyppi</label>
                <select class="form-control" id="type" v-model="selectedInterface.type">
                    <option v-for="type in interfaceTypes" :value="type.id">{{ type.name }}</option>
                </select>
            </div>
            <div class="form-check py-3">
                <input class="form-check-input" type="checkbox" value="" id="onDropdown" v-model="selectedInterface.onDropdown">
                <label for="onDropdown" class="form-check-label">Näytä rajapinta valikossa</label>
            </div>
            <div class="form-group">
                <label for="defaultUser" class="col-form-label">Oletuskäyttäjä</label>
                <select class="form-control" id="defaultUser" v-model="selectedInterface.defaultUser">
                    <option v-for="user in users.list" :value="user.id">{{ user.username }}</option>
                </select>
            </div>
            <hr/>
            <h5>Rest API</h5>
            <hr>
            <div class="form-group">
                <label for="restUrl" class="col-form-label">Osoite</label>
                <input type="text" class="form-control" id="restUrl" placeholder="Osoite" v-model="selectedInterface.restUrl">
                <small id="restUrlHelp" class="form-text text-muted">Esim. https://tati.koha-suomi.fi</small>
            </div>
            <div v-if="selectedInterface.type === 'export'">
              <div class="form-group">
                  <div class="row">
                      <div class="col-9">
                        <label for="restSearch" class="col-form-label">Search-endpoint</label>
                        <input type="text" class="form-control" id="restSearch" v-model="selectedInterface.restSearch">
                        <small id="restSearchHelp" class="form-text text-muted">Esim. /api/v1/contrib/kohasuomi/broadcast/biblios/</small>
                      </div>
                      <div class="col-3">
                        <label for="restGetMethod" class="col-form-label">Method</label>
                        <select class="form-control" id="restSearchMethod" v-model="selectedInterface.restSearchMethod">
                            <option selected value="">Valitse</option>
                            <option value="get">GET</option>
                            <option value="post">POST</option>
                        </select>
                      </div>
                    </div>
              </div>
              <div class="form-group">
                  <div class="row">
                      <div class="col-9">
                        <label for="restGet" class="col-form-label">Get-endpoint</label>
                        <input type="text" class="form-control" id="restGet" v-model="selectedInterface.restGet">
                        <small id="restGetHelp" class="form-text text-muted">Esim. /api/v1/contrib/kohasuomi/broadcast/biblios/{biblio_id}</small>
                      </div>
                      <div class="col-3">
                        <label for="restGetMethod" class="col-form-label">Method</label>
                        <select class="form-control" id="restGetMethod" v-model="selectedInterface.restGetMethod">
                            <option selected value="">Valitse</option>
                            <option value="get">GET</option>
                            <option value="post">POST</option>
                        </select>
                      </div>
                    </div>
              </div>
              <div class="form-group">
                  <div class="row">
                      <div class="col-9">
                        <label for="restPost" class="col-form-label">Add-endpoint</label>
                        <input type="text" class="form-control" id="restAdd" v-model="selectedInterface.restAdd">
                        <small id="restAddHelp" class="form-text text-muted">Esim. /api/v1/contrib/kohasuomi/broadcast/biblios/</small>
                      </div>
                      <div class="col-3">
                        <label for="restAddMethod" class="col-form-label">Method</label>
                        <select class="form-control" id="restAddMethod" v-model="selectedInterface.restAddMethod">
                            <option selected value="">Valitse</option>
                            <option value="post">POST</option>
                            <option value="put">PUT</option>
                        </select>
                      </div>
                    </div>
              </div>
              <div class="form-group">
                  <div class="row">
                      <div class="col-9">
                        <label for="restPut" class="col-form-label">Update-endpoint</label>
                        <input type="text" class="form-control" id="restUpdate" v-model="selectedInterface.restUpdate">
                        <small id="restUpdateHelp" class="form-text text-muted">Esim. /api/v1/contrib/kohasuomi/broadcast/biblios/{biblio_id}</small>
                      </div>
                      <div class="col-3">
                        <label for="restAddMethod" class="col-form-label">Method</label>
                        <select class="form-control" id="restUpdateMethod" v-model="selectedInterface.restUpdateMethod">
                            <option selected value="">Valitse</option>
                            <option value="post">POST</option>
                            <option value="put">PUT</option>
                        </select>
                      </div>
                  </div>
              </div>
              <div class="form-group">
                  <label for="restDelete" class="col-form-label">Delete-endpoint</label>
                  <input type="text" class="form-control" id="restDelete" v-model="selectedInterface.restDelete">
                  <small id="restDeleteHelp" class="form-text text-muted">Esim. /api/v1/contrib/kohasuomi/broadcast/biblios/{biblio_id}</small>
              </div>
              <hr/>
              <h5>SRU-haku</h5>
              <hr>
              <div class="form-group">
                  <label for="sruUrl" class="col-form-label">Osoite</label>
                  <input type="text" class="form-control" id="sruUrl" v-model="selectedInterface.sruUrl">
              </div>
            </div>
            <hr/>
        </div>
        <div class="form-group">
            <button type="button" class="btn btn-primary" @click="save()">Tallenna</button>
        </div>
    </form>
    `,
};
