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
      reports: [],
      activeLinkStyle: {
        'background-color': '#007bff',
        'color': '#fff',
      },
      selectedInterface: '',
      localRecord: '',
      remoteRecord: '',
      localEncodingLevel: '',
      remoteEncodingLevel: '',
      localStatus: '',
      remoteStatus: '',
      showExportButton: false,
      remoteRecordId: '',
      disabled: false,
    };
  },
  created() {
    this.config.fetch();
    this.records.getLocal(this.biblio_id);
  },
  computed: {
    isDisabled() {
      return this.disabled;
    }
  },
  methods: {
    search() {
      this.loader = true;
      this.records.search(this.biblio_id, this.selectedInterface).then((response) => {
        this.remoteRecord = recordParser.recordAsHTML(response.data.marcjson);
        this.remoteEncodingLevel = recordParser.recordEncodingLevel(response.data.marcjson);
        this.remoteStatus = recordParser.recordStatus(response.data.marcjson);
        this.remoteRecordId = recordParser.recordId(response.data.marcjson);
        this.loader = false;
      } ).catch((error) => {
        this.errors.setError(error);
        this.loader = false;
      }).finally(() => {
        this.localRecord = recordParser.recordAsHTML(this.records.marcjson);
        this.localEncodingLevel = recordParser.recordEncodingLevel(this.records.marcjson);
        this.localStatus = recordParser.recordStatus(this.records.marcjson);
        this.compareRecords();
      });
    },
    importRecord() {
      this.records.transfer(this.biblio_id, this.patron_id, this.selectedInterface, this.remoteRecordId, 'import');
      this.disabled = true;
    },
    exportRecord() {
      this.records.transfer(this.biblio_id, this.patron_id, this.selectedInterface, this.remoteRecordId, 'export');
    },
    openModal(event) {
      this.selectedInterface = event.target.text;
      const modal = $('#pushRecordOpModal');
      modal.modal('show');
      this.search();
    },
    compareRecords() {
      // Compare encoding levels and statuses to determine if export button should be shown
      if (this.localEncodingLevel < this.remoteEncodingLevel && this.localEncodingLevel != 'u' && this.localEncodingLevel != 'z') {
        this.showExportButton = true;
      } else if (this.localEncodingLevel == this.remoteEncodingLevel) {
          if (this.localStatus == 'c' && this.remoteStatus == 'n') {
            this.showExportButton = true;
          } else if (this.localStatus == 'n' && this.remoteStatus == 'c') {
            this.showExportButton = false;
          } else {
            this.showExportButton = true;
          }
      } else if (this.localEncodingLevel == 4 && this.remoteEncodingLevel == 3) {
        this.showExportButton = true;
      } else if (this.localEncodingLevel == '') {
        this.showExportButton = true;
      }
      const systemControlNumbers = recordParser.systemControlNumbers(this.records.marcjson);
      var hasMelinda = systemControlNumbers.find(a =>a.includes("MELINDA"));
      if (!hasMelinda && this.selectedInterface.includes('Melinda')) {
        this.showExportButton = false;
      }
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
            <div class="alert alert-danger" role="alert" v-if="errors.errors.length > 0">
              <b>Tapahtui virhe:</b>
              <ul class="text-danger">
                <li v-for="error in errors.errors">{{ error }}</li>
              </ul>
            </div>
            <div v-if="records.saved" class="alert alert-success" role="alert">
              Lisätty jonoon!
            </div>
            <div class="row">
              <div v-html="localRecord" class="col-sm-6" :class="{ 'col-sm-8': !remoteRecord }"></div>
              <div v-if="remoteRecord" v-html="remoteRecord" class="col-sm-6"></div>
            </div>
          </div>
          <div class="modal-footer">
            <button v-if="showExportButton" class="btn btn-secondary" style="float:none;" @click="exportRecord()">Vie</button>\
            <button class="btn btn-primary" style="float:none;" @click="importRecord()" :disabled="isDisabled">Tuo</button>\
            <button type="button" class="btn btn-default" data-dismiss="modal" style="float:none;">Sulje</button>\
          </div>
        </div>
      </div>
    </div>
    `,
};
