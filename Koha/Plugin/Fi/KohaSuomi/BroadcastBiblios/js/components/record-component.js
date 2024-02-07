import { useConfigStore } from "../stores/config-store.js";
import { useErrorStore } from "../stores/error-store.js";
import { useRecordStore } from "../stores/record-store.js";
import * as recordParser from '../recordParser.js';

export default {
  props: ['biblio_id', 'patron_id'],
  setup() {
    const configStore = useConfigStore();
    const errorStore = useErrorStore();
    const recordStore = useRecordStore();
    return {
      config: configStore,
      errors: errorStore,
      records: recordStore,
    };
  },
  data() {
    return {
      showRecord: true,
      loader: true,
      username: '',
      reports: [],
      activeLinkStyle: {
        'background-color': '#007bff',
        'color': '#fff',
      },
      selectedInterface: '',
      localRecord: '',
      remoteRecord: '',
    };
  },
  created() {
    this.config.fetch();
    this.records.getLocal(this.biblio_id);
  },
  methods: {
    search() {
      this.loader = true;
      this.records.search(this.biblio_id, this.selectedInterface).then((response) => {
        this.remoteRecord = recordParser.recordAsHTML(response.data.marcjson);
        this.loader = false;
      } ).catch((error) => {
        this.errors.setError(error);
        this.loader = false;
      }).finally(() => {
        this.localRecord = recordParser.recordAsHTML(this.records.marcjson);
      });
    },
    openModal(event) {
      this.selectedInterface = event.target.text;
      const modal = $('#pushRecordOpModal');
      modal.modal('show');
      this.search();
    },
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
      <div class="modal-dialog" :class="{'modal-lg': remoteRecord}">
        <div class="modal-content">
          <div class="modal-header">
            <ul class="nav nav-pills">
              <li class="nav-item">
                <a class="nav-link active" href="#" @click="search()">Siirto</a>
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
            <div class="row">
              <div v-html="localRecord" class="col-sm-6" :class="{ 'col-sm-8': !remoteRecord }"></div>
              <div v-if="remoteRecord" v-html="remoteRecord" class="col-sm-6"></div>
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
