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
      showImportButton: true,
      interfaceType: '',
      remoteRecordId: null,
      disabled: false,
      componentPartsEqual: true,
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
      this.remoteRecord = '';
      this.showExportButton = false;
      this.showImportButton = true;
      this.errors.clear();
      this.records.saved = false;
      this.loader = true;
      this.records.search(this.biblio_id, this.selectedInterface).then((response) => {
        if (Object.keys(response.data.marcjson).length > 0) {
          this.remoteRecord = recordParser.recordAsHTML(response.data.marcjson);
          this.remoteEncodingLevel = recordParser.recordEncodingLevel(response.data.marcjson);
          this.remoteStatus = recordParser.recordStatus(response.data.marcjson);
          this.remoteRecordId = recordParser.recordId(response.data.marcjson);
        }
        this.interfaceType = this.config.interfaceType(this.selectedInterface);
        this.loader = false;
      } ).catch((error) => {
        this.errors.setError(error);
        this.loader = false;
      }).finally(() => {
        this.localRecord = recordParser.recordAsHTML(this.records.marcjson);
        this.localEncodingLevel = recordParser.recordEncodingLevel(this.records.marcjson);
        this.localStatus = recordParser.recordStatus(this.records.marcjson);
        if (this.remoteRecord) {
          this.compareRecords();
        } else {
          this.showImportButton = false;
          if (this.interfaceType == 'export') {
            this.showExportButton = true;
          }
        }
        this.checkComponentParts();
      });
    },
    importRecord() {
      this.records.transfer(this.biblio_id, this.patron_id, this.selectedInterface, this.remoteRecordId, 'import');
      this.disabled = true;
    },
    exportRecord() {
      this.records.transfer(this.biblio_id, this.patron_id, this.selectedInterface, this.remoteRecordId, 'export');
    },
    async exportComponentParts() {
      for (const part of this.records.componentparts) {
        const response = await this.processPart(part);
        if (response.status == 200 || response.status == 201) {
          this.records.saved = true;
          this.errors.clear();
        }
      }
    },
    async processPart(part) {
      const biblio_id = part.biblionumber;
      const linkIdentifier = recordParser.hostComponentPartLink(this.records.remotemarcjson);
      const marcjson = recordParser.updateLinkField(part.marcjson, linkIdentifier);
      return this.records.transferComponentPart(biblio_id, this.patron_id, this.selectedInterface, 'export', marcjson);
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

      const localTimestamp = recordParser.recordTimestamp(this.records.marcjson);
      const remoteTimestamp = recordParser.recordTimestamp(this.records.remotemarcjson);
      if (localTimestamp < remoteTimestamp) {
        this.showExportButton = false;
      }
    },
    checkComponentParts() {
      let localParts = this.records.componentparts.length;
      let remoteParts = 0;
      if (this.records.remotecomponentparts) {
        remoteParts = this.records.remotecomponentparts.length;
      }
      if (localParts != remoteParts && remoteParts == 0 && this.remoteRecord) {
        this.componentPartsEqual = false;
        this.errors.setError("Osakohteiden määrä ei täsmää: " + localParts + " vs. " + remoteParts);
      } 
    }
  },
  template: `
    <div v-if="config.onDropdown.length > 0" class="btn-group" style="margin-left: 5px;">
      <button class="btn btn-default dropdown-toggle" data-toggle="dropdown"><i class="fa fa-upload"></i> Vie/Tuo <span class="caret"></span></button>
      <ul id="pushInterfaces" class="dropdown-menu">
        <li v-for="interface in config.onDropdown" :key="interface.name">
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
            <button v-if="showExportButton && interfaceType == 'export'" class="btn btn-secondary" style="float:none;" @click="exportRecord()">Vie</button>\
            <button v-if="componentPartsEqual && showImportButton" class="btn btn-primary" style="float:none;" @click="importRecord()" :disabled="isDisabled">Tuo</button>\
            <button v-if="!componentPartsEqual && interfaceType == 'export'" class="btn btn-danger" style="float:none;" @click="exportComponentParts()">Vie osakohteet</button>\
            <button type="button" class="btn btn-default" data-dismiss="modal" style="float:none;">Sulje</button>\
          </div>
        </div>
      </div>
    </div>
    `,
};
