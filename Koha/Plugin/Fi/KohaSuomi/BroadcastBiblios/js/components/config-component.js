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
  computed: {
    config() {
      return this.config;
    },
    users() {
      return this.users;
    },
    errors() {
      return this.errors;
    },
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
      if (newInterface && this.selectedInterface.name !== "" && Object.keys(this.selectedInterface).length > 0){
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
      if (!this.selectedInterface.defaultUser) {
        this.errors.setError("Oletuskäyttäjä on pakollinen");
        valid = false;
      }
      if ((this.selectedInterface.restUrl === undefined || this.selectedInterface.restUrl === "") && this.selectedInterface.sruUrl === undefined || this.selectedInterface.sruUrl === "") {
        this.errors.setError("REST URL tai SRU URL on pakollinen");
        valid = false;
      }
      return valid;
    }
  },
  template: `
    <div v-if="errors.errors.length > 0" class="alert alert-danger" role="alert">
        <div v-for="error in errors.errors">{{ error }}</div>
    </div>
    <div v-if="config.saved" class="alert alert-success" role="alert">
        Asetukset tallennettu
    </div>
    <form>
        <div class="form-group row">
            <div class="col-9">
                <select class="form-control" id="interfaces" @change="selectedInterfaceChanged($event)" v-model="interfaceName">
                    <option selected value="">Valitse siirtorajapinta</option>
                    <option v-for="interface in config.interfaces" :value="interface.name">{{ interface.name }}</option>
                </select>
            </div>
            <div class="col-3">
                <button type="button" class="btn btn-success" @click="addInterface()">Uusi</button>
                <button type="button" :class="interfaceName ? 'btn-danger' : 'btn-grey'" class="btn" @click="removeInterface()" :disabled="!interfaceName">Poista</button>
            </div>
        </div>
        <hr/>
        <div v-show="showInterface">
            <h5>Siirtorajapinnan tiedot</h5>
            <hr>
            <div class="form-group">
                <label for="name" class="col-form-label">Siirtorajapinnan nimi</label>
                <input type="text" class="form-control" id="name" v-model="selectedInterface.name">
            </div>
            <div class="form-group">
                <label for="type" class="col-form-label">Siirtorajapinnan tyyppi</label>
                <select class="form-control" id="type" v-model="selectedInterface.type">
                    <option v-for="type in interfaceTypes" :value="type.id">{{ type.name }}</option>
                </select>
            </div>
            <div class="form-group">
                <label for="defaultUser" class="col-form-label">Oletuskäyttäjä</label>
                <select class="form-control" id="defaultUser" v-model="selectedInterface.defaultUser">
                    <option v-for="user in users.list" :value="user.id">{{ user.username }}</option>
                </select>
            </div>
            <div class="form-group">
                <label for="RESTurl" class="col-form-label">Siirtorajapinnan REST URL</label>
                <input type="text" class="form-control" id="RESTurl" v-model="selectedInterface.restUrl">
            </div>
            <div class="form-group">
                <label for="SRUurl" class="col-form-label">Siirtorajapinnan SRU URL</label>
                <input type="text" class="form-control" id="SRUurl" v-model="selectedInterface.sruUrl">
            </div>
            <hr/>
        </div>
        <div class="form-group">
            <label for="name" class="col-form-label">Ilmoita kentistä (erota pilkulla):</label>
            <input type="text" class="form-control" id="notifyfields" v-model="config.notifyfields">
        </div>
        <hr/>
        <div class="form-group">
            <button type="button" class="btn btn-primary" @click="save()">Tallenna</button>
        </div>
    </form>
    `,
};
