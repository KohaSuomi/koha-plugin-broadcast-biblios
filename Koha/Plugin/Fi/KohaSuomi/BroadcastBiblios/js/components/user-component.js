import { useErrorStore } from "../stores/error-store.js";
import { useUserStore } from "../stores/user-store.js";
import { useConfigStore } from "../stores/config-store.js";

export default {
  setup() {
    const errorStore = useErrorStore();
    const userStore = useUserStore();
    const config = useConfigStore();
    return {
      errors: errorStore,
      users: userStore,
      config: config,
    };
  },
  data() {
    return {
        showUser: false,
        selectedUser: {},
        userId: '',
        authTypes: [
            { id: "basic", name: "Basic" },
            { id: "oauth", name: "OAuth" },
        ],
    };
  },
  computed: {
    interfaces() {
        return this.config.interfaces;
    }
  },
  created() {
    this.users.fetch();
  },
  methods: {
    async selectedUserChanged(event) {
        this.showUser = true;
        this.userId = event.target.value;
        if (!this.userId) {
            this.selectedUser = {};
            this.showUser = false;
            return;
        }
        this.selectedUser = await this.users.get(this.userId);
    },
    async save() {
        this.users.saved = false;
        const valid = await this.isValid();
        if (valid) {
            if (this.userId) {
                this.users.update();
            } else {
                this.users.user = this.selectedUser;
                this.users.save();
            }
            this.userId = '';
            this.selectedUser = {};
            this.showUser = false;
        }
    },
    async deleteUser() {
        this.users.delete();
        this.userId = '';
        this.selectedUser = {};
        this.showUser = false;
    },
    async addUser() {
        this.showUser = true;
        this.selectedUser = {};
        this.userId = '';
    },
    async isValid() {
        this.errors.clear();
        if (!this.selectedUser.username) {
            this.errors.setError("Tunnus puuttuu");
        }
        if (!this.selectedUser.auth_type) {
            this.errors.setError("Autentikaatiotapa puuttuu");
        }
        if (this.selectedUser.auth_type === "oauth") {
            if (!this.selectedUser.client_id) {
                this.errors.setError("Client id puuttuu");
            }
            if (!this.selectedUser.client_secret) {
                this.errors.setError("Client secret puuttuu");
            }
            if (!this.selectedUser.access_token_url) {
                this.errors.setError("Token URL puuttuu");
            }
        }
        if (this.errors.errors.length > 0) {
            return false;
        }
        return true;
    }
  },
  template: `
    <div v-if="errors.errors.length > 0" class="alert alert-danger" role="alert">
        <div v-for="error in errors.errors">{{ error }}</div>
    </div>
    <div v-if="users.saved" class="alert alert-success" role="alert">
        Käyttäjä tallennettu
    </div>
    <form>
        <div class="form-group row">
            <div class="col-9">
                <select class="form-control" id="usersList" @change="selectedUserChanged($event)" v-model="userId">
                    <option selected value="">Valitse käyttäjä</option>
                    <option v-for="user in users.list" :value="user.id">{{ user.username }} ({{user.broadcast_interface}})</option>
                </select>
            </div>
            <div class="col-3">
                <button type="button" class="btn btn-success" @click="addUser()">Uusi</button>
                <button type="button" :class="userId ? 'btn-danger' : 'btn-grey'" class="btn" @click="deleteUser()" :disabled="!userId">Poista</button>
            </div>
        </div>
        <div v-show="showUser">
            <hr/>
            <h5>Käyttäjä</h5>
            <div class="form-group">
                <label for="username" class="col-form-label">Tunnus</label>
                <input type="text" class="form-control" id="username" v-model="selectedUser.username">
            </div>
            <div class="form-group">
                <label for="password" class="col-form-label">Salasana</label>
                <input type="password" class="form-control" id="password" v-model="selectedUser.password">
            </div>
            <div class="form-group">
                <label for="broadcastInterface" class="col-form-label">Rajapinta</label>
                <select class="form-control" id="broadcastInterface" v-model="selectedUser.broadcast_interface">
                    <option selected value="">Valitse</option>
                    <option v-for="interface in interfaces" :value="interface.name">{{ interface.name }}</option>
                </select>
            </div>
            <div class="form-group">
                <label for="type" class="col-form-label">Autentikaatiotapa</label>
                <select class="form-control" id="type" v-model="selectedUser.auth_type">
                    <option selected value="">Valitse</option>
                    <option v-for="type in authTypes" :value="type.id">{{ type.name }}</option>
                </select>
            </div>
            <div class="form-group">
                <label for="clientId" class="col-form-label">Client id</label>
                <input type="text" class="form-control" id="clientId" v-model="selectedUser.client_id">
            </div>
            <div class="form-group">
                <label for="clientSecret" class="col-form-label">Client secret</label>
                <input type="text" class="form-control" id="clientId" v-model="selectedUser.client_secret">
            </div>
            <div class="form-group">
                <label for="AccessURL" class="col-form-label">Token URL</label>
                <input type="text" class="form-control" id="AccessURL" v-model="selectedUser.access_token_url">
            </div>
            <div class="form-group">
                <label for="LinkedUser" class="col-form-label">Linkitetty käyttäjä (borrowernumber)</label>
                <input type="text" class="form-control" id="LinkedUser" v-model="selectedUser.linked_borrowernumber">
            </div>
        </div>
        <hr/>
        <div class="form-group">
            <button type="button" class="btn btn-primary" @click="save()">Tallenna</button>
        </div>
    </form>
    `,
};
