import { useConfigStore } from "../stores/config-store.js";
import { useErrorStore } from "../stores/error-store.js";
import { useUserStore } from "../stores/user-store.js";
import { t } from "../helpers/translations.js";

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
        { id: "import", name: t("Tuonti") },
        { id: "export", name: t("Vienti") },
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
      this.errors.clear();
      let valid = true;
      if (!this.selectedInterface.name) {
        this.errors.setError(t("Nimi on pakollinen"));
        valid = false;
      }
      if (!this.selectedInterface.type) {
        this.errors.setError(t("Tyyppi on pakollinen"));
        valid = false;
      }
      if (
        (this.selectedInterface.restUrl === undefined && this.selectedInterface.restUrl === "") ||
        (this.selectedInterface.sruUrl === undefined && this.selectedInterface.sruUrl === "")
      ) {
        this.errors.setError(t("REST URL tai SRU URL on pakollinen"));
        valid = false;
      }
      if (
        this.selectedInterface.restUrl &&
        !this.validateHttpUrl(this.selectedInterface.restUrl)
      ) {
        this.errors.setError(t("REST URL ei ole validi"));
        valid = false;
      }
      if (
        this.selectedInterface.sruUrl &&
        !this.validateHttpUrl(this.selectedInterface.sruUrl)
      ) {
        this.errors.setError(t("SRU URL ei ole validi"));
        valid = false;
      }
      if (this.config.activationInterface && this.selectedInterface.activationInterface && this.config.activationInterface !== this.selectedInterface.name) {
        this.errors.setError(t("Vain yksi aktivointirajapinta voi olla aktiivinen"));
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
        {{ t('Asetukset tallennettu') }}
    </div>
    <form>
    <div class="form-group">
      <label for="name" class="col-form-label">{{ t('Ilmoita kentistä (erota pilkulla):') }}</label>
      <input type="text" class="form-control" id="notifyfields" v-model="config.notifyfields">
    </div>
    <hr/>
        <div class="form-group row">
            <div class="col-9">
                <select class="form-control" id="interfaces" @change="selectedInterfaceChanged($event)" v-model="interfaceName">
                    <option selected value="">{{ t('Valitse siirtorajapinta') }}</option>
                    <option v-for="interface in config.interfaces" :value="interface.name">{{ interface.name }}</option>
                </select>
            </div>
            <div class="col-3">
                <button type="button" class="btn btn-success mr-2" @click="addInterface()">{{ t('Uusi') }}</button>
                <button type="button" :class="interfaceName ? 'btn-danger' : 'btn-grey'" class="btn" @click="removeInterface()" :disabled="!interfaceName">{{ t('Poista') }}</button>
            </div>
        </div>
        <hr/>
        <div v-show="showInterface">
            <h5>{{interfaceName}}-{{ t('rajapinnan tiedot') }}</h5>
            <hr>
            <div class="form-group">
                <label for="name" class="col-form-label">{{ t('Nimi') }}</label>
                <input type="text" class="form-control" id="name" v-model="selectedInterface.name">
            </div>
            <div class="form-group">
                <label for="type" class="col-form-label">{{ t('Tyyppi') }}</label>
                <select class="form-control" id="type" v-model="selectedInterface.type">
                    <option selected value="">{{ t('Valitse') }}</option>
                    <option v-for="type in interfaceTypes" :value="type.id">{{ type.name }}</option>
                </select>
            </div>
            <div class="form-group">
                <label for="parentInterface" class="col-form-label">{{ t('Ylärajapinta (valinnainen)') }}</label>
                <select class="form-control" id="parentInterface" v-model="selectedInterface.parentInterface">
                    <option selected value="">{{ t('Valitse') }}</option>
                    <option v-for="interface in config.interfaces" :value="interface.name">{{ interface.name }}</option>
                </select>
            </div>
            <div class="form-check py-3">
                <input class="form-check-input" type="checkbox" value="" id="activationInterface" v-model="selectedInterface.activationInterface">
                <label for="activationInterface" class="form-check-label">{{ t('Tietueiden aktivointirajapinta') }}</label>
            </div>
            <div class="form-check py-3">
                <input class="form-check-input" type="checkbox" value="" id="onDropdown" v-model="selectedInterface.onDropdown">
                <label for="onDropdown" class="form-check-label">{{ t('Näytä rajapinta valikossa') }}</label>
            </div>
            <div class="form-group">
                <label for="defaultUser" class="col-form-label">{{ t('Tuonnin oletuskäyttäjä') }}</label>
                <select class="form-control" id="defaultUser" v-model="selectedInterface.defaultUser">
                    <option selected value="">{{ t('Valitse') }}</option>
                    <option v-for="user in users.list" :value="user.id">{{ user.username }}</option>
                </select>
            </div>
            <hr/>
            <h5>Rest API</h5>
            <hr>
            <div class="form-group">
                <label for="restUrl" class="col-form-label">{{ t('Osoite') }}</label>
                <input type="text" class="form-control" id="restUrl" :placeholder="t('Osoite')" v-model="selectedInterface.restUrl">
                <small id="restUrlHelp" class="form-text text-muted">{{ t('Esim. https://tati.koha-suomi.fi') }}</small>
            </div>
            <div class="form-group">
                <div class="row">
                  <div class="col-9">
                    <label for="restSearch" class="col-form-label">{{ t('Search-endpoint') }}</label>
                    <input type="text" class="form-control" id="restSearch" v-model="selectedInterface.restSearch">
                    <small id="restSearchHelp" class="form-text text-muted">{{ t('Esim. /api/v1/contrib/kohasuomi/broadcast/biblios/') }}</small>
                  </div>
                  <div class="col-3">
                    <label for="restGetMethod" class="col-form-label">{{ t('Method') }}</label>
                    <select class="form-control" id="restSearchMethod" v-model="selectedInterface.restSearchMethod">
                        <option selected value="">{{ t('Valitse') }}</option>
                        <option value="get">GET</option>
                        <option value="post">POST</option>
                    </select>
                  </div>
                </div>
            </div>
            <div v-if="selectedInterface.type === 'export'">
              <div class="form-group">
                  <div class="row">
                      <div class="col-9">
                        <label for="restPost" class="col-form-label">{{ t('Add-endpoint') }}</label>
                        <input type="text" class="form-control" id="restAdd" v-model="selectedInterface.restAdd">
                        <small id="restAddHelp" class="form-text text-muted">{{ t('Esim. /api/v1/contrib/kohasuomi/broadcast/biblios/') }}</small>
                      </div>
                      <div class="col-3">
                        <label for="restAddMethod" class="col-form-label">{{ t('Method') }}</label>
                        <select class="form-control" id="restAddMethod" v-model="selectedInterface.restAddMethod">
                            <option selected value="">{{ t('Valitse') }}</option>
                            <option value="post">POST</option>
                            <option value="put">PUT</option>
                        </select>
                      </div>
                    </div>
              </div>
              <div class="form-group">
                  <div class="row">
                      <div class="col-9">
                        <label for="restPut" class="col-form-label">{{ t('Update-endpoint') }}</label>
                        <input type="text" class="form-control" id="restUpdate" v-model="selectedInterface.restUpdate">
                        <small id="restUpdateHelp" class="form-text text-muted">{{ t('Esim. /api/v1/contrib/kohasuomi/broadcast/biblios/{biblio_id}') }}</small>
                      </div>
                      <div class="col-3">
                        <label for="restAddMethod" class="col-form-label">{{ t('Method') }}</label>
                        <select class="form-control" id="restUpdateMethod" v-model="selectedInterface.restUpdateMethod">
                            <option selected value="">{{ t('Valitse') }}</option>
                            <option value="post">POST</option>
                            <option value="put">PUT</option>
                        </select>
                      </div>
                  </div>
              </div>
              <hr/>
              <h5>SRU-haku</h5>
              <hr>
              <div class="form-group">
                  <label for="sruUrl" class="col-form-label">{{ t('Osoite') }}</label>
                  <input type="text" class="form-control" id="sruUrl" v-model="selectedInterface.sruUrl">
              </div>
            </div>
            <hr/>
        </div>
        <div class="form-group">
            <button type="button" class="btn btn-primary" @click="save()">{{ t('Tallenna') }}</button>
        </div>
    </form>
    `,
  methods: {
    t // expose t to template
  }
};
