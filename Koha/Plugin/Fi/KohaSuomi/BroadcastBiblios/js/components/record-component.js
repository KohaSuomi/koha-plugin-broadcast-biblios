import { useConfigStore } from "../stores/config-store.js";
import { useErrorStore } from "../stores/error-store.js";
import { useUserStore } from "../stores/user-store.js";

export default {
  props: ['biblio_id', 'patron_id'],
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
      showRecord: true,
      loader: false,
      username: '',
      reports: [],
      activeLinkStyle: {
        'background-color': '#007bff',
        'color': '#fff',
      },
      selectedInterface: '',
    };
  },
  created() {
    this.config.fetch();
  },
  methods: {
    openModal(event) {
      event.preventDefault();
      this.selectedInterface = event.target.text;
      const modal = $('#pushRecordOpModal');
      modal.modal('show');
    }
  },
  template: `
    <div class="btn-group" style="margin-left: 5px;">
      <button class="btn btn-default dropdown-toggle" data-toggle="dropdown"><i class="fa fa-upload"></i> Vie/Tuo <span class="caret"></span></button>
      <ul id="pushInterfaces" class="dropdown-menu">
        <li v-for="interface in config.exportInterfaces" :key="interface.name">
          <a href="#" @click="openModal($event)">{{ interface.name }}</a>
        </li>
      </ul>
    </div>
    <div id="pushRecordOpModal" class="modal fade" role="dialog">
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <ul class="nav nav-pills">
              <li class="nav-item">
                <a class="nav-link active" href="#">Siirto</a>
              </li>
              <li class="nav-item">
                <a class="nav-link" href="#">Tapahtumat</a>
              </li>
            </ul>
          </div>
          <div class="modal-body">
            <div v-if="loader" id="spinner-wrapper" class="text-center">
              <i class="fa fa-spinner fa-spin" style="font-size:36px"></i>
            </div>
            <div class="alert alert-danger" role="alert" v-if="errors.length">
              <b>Tapahtui virhe:</b>
              <ul class="text-danger">
                <li v-for="error in errors">{{ error }}</li>
              </ul>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-secondary" style="float:none;">Vie</button>\
            <button class="btn btn-primary" style="float:none;">Tuo</button>\
            <button type="button" class="btn btn-default" data-dismiss="modal" style="float:none;">Sulje</button>\
          </div>
        </div>
      </div>
    </div>
    `,
};
