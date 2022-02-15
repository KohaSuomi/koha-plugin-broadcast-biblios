const recordModal = Vue.component('recordmodal', {
  template:
    '<div id="pushRecordOpModal" class="modal fade" role="dialog">\
        <div class="modal-dialog" :class="{\'modal-lg\': target}">\
            <div class="modal-content">\
                <div class="modal-header">\
                    <ul class="nav nav-pills">\
                        <li class="nav-item">\
                            <a id="exporter" class="nav-link" style="background-color:#007bff; color:#fff;" href="#">Siirto<i class="fa fa-refresh" style="margin-left:7px;"></i></a>\
                        </li>\
                        <li class="nav-item">\
                            <a id="report" class="nav-link" href="#">Tapahtumat<i class="hidden fa fa-refresh" style="margin-left:7px;"></i></a>\
                        </li>\
                    </ul>\
                </div>\
                <div v-if="loader" id="spinner-wrapper" class="modal-body text-center">\
                    <i class="fa fa-spinner fa-spin" style="font-size:36px"></i>\
                </div>\
                <div class="alert alert-danger" role="alert" v-if="errors.length">\
                  <b>Tapahtui virhe:</b>\
                  <ul class="text-danger">\
                    <li v-for="error in errors">{{ error }}</li>\
                  </ul>\
                </div>\
                <div id="exportRecordWrapper" class="modal-body">\
                  <div id="exportRecord">\
                    <div v-if="target" ><span class="col-sm-6"><h3>Paikallinen</h3><hr/></span><span class="col-sm-6"><h3> {{exportapi.interface}} </h3><hr/></span></div>\
                    <div class="col-sm-6" v-html="source"></div>\
                    <div v-if="target" class="col-sm-6" v-html="target"></div>\
                  </div>\
                </div>\
                <div id="report-wrapper" class="modal-body hidden">\
                </div>\
                <div class="modal-footer">\
                    <button type="button" @click="exportRecord()" class="btn btn-success" style="float:none;">Vie</button>\
                    <button type="button" class="btn btn-primary" style="float:none;">Tuo</button>\
                    <button type="button" class="btn btn-default" data-dismiss="modal" style="float:none;">Sulje</button>\
                </div>\
            </div>\
        </div>\
        </div>',
  props: [
    'source',
    'target',
    'errors',
    'biblionumber',
    'exportapi',
    'importapi',
  ],
  data() {
    return {
      loader: false,
    };
  },
  methods: {
    exportRecord() {
      alert('jee');
    },
  },
});

new Vue({
  el: '#pushApp',
  components: {
    recordModal,
  },
  data() {
    return {
      errors: [],
      exportapi: {},
      importapi: {},
      biblionumber: 0,
      record: '',
      source: '',
      target: '',
    };
  },
  created() {
    const interface = document.getElementById('importInterface');
    this.importapi.interface = interface.textContent;
    this.importapi.host = interface.getAttribute('data-host');
    this.importapi.basePath = interface.getAttribute('data-basepath');
    this.importapi.searchPath = interface.getAttribute('data-searchpath');
    this.importapi.reportPath = interface.getAttribute('data-reportpath');
    this.importapi.token = interface.getAttribute('data-token');
    this.importapi.type = interface.getAttribute('data-type');

    const queryString = window.location.search;
    const urlParams = new URLSearchParams(queryString);
    this.biblionumber = urlParams.get('biblionumber');
    this.getRecord();
  },
  methods: {
    openModal(e) {
      e.preventDefault();
      this.exportapi.interface = e.target.textContent;
      this.exportapi.host = e.target.getAttribute('data-host');
      this.exportapi.basePath = e.target.getAttribute('data-basepath');
      this.exportapi.searchPath = e.target.getAttribute('data-searchpath');
      this.exportapi.reportPath = e.target.getAttribute('data-reportpath');
      this.exportapi.token = e.target.getAttribute('data-token');
      this.exportapi.type = e.target.getAttribute('data-type');
      this.searchRemoteRecord();
    },
    getRecord() {
      axios
        .get(
          '/api/v1/contrib/kohasuomi/biblios/' +
            this.biblionumber +
            '/componentparts',
          {
            headers: {
              Accept: 'application/marcxml+xml',
            },
          }
        )
        .then((response) => {
          this.record = response.data;
        })
        .catch((error) => {});
    },
    searchRemoteRecord() {
      this.errors = [];
      const body = {
        marcxml: this.record,
        interface: this.exportapi.interface,
      };
      const headers = { Authorization: this.exportapi.token };
      axios
        .post(this.exportapi.host + this.exportapi.searchPath, body, {
          headers,
        })
        .then((response) => {
          console.log(response);
          this.source = this.parseRecord(response.data.sourcerecord);
          if (response.data.targetrecord) {
            this.target = this.parseRecord(response.data.targetrecord);
          }
        })
        .catch((error) => {
          this.errorMessage(error);
        });
    },
    parseRecord(record) {
      var html = '<div>';
      html +=
        '<li class="row" style="list-style:none;"> <div class="col-xs-3 mr-2">';
      html +=
        '<b>000</b></div><div class="col-xs-9">' + record.leader + '</li>';
      record.fields.forEach(function (v, i, a) {
        if ($.isNumeric(v.tag)) {
          html +=
            '<li class="row" style="list-style:none;"><div class="col-xs-3 mr-2">';
        } else {
          html += '<li class="row hidden"><div class="col-xs-3  mr-2">';
        }
        html += '<b>' + v.tag;
        if (v.ind1) {
          html += ' ' + v.ind1;
        }
        if (v.ind2) {
          html += ' ' + v.ind2;
        }
        html += '</b></div><div class="col-xs-9">';
        if (v.subfields) {
          v.subfields.forEach(function (v, i, a) {
            html += '<b>_' + v.code + '</b>' + v.value + '<br/>';
          });
        } else {
          html += v.value;
        }
        html += '</div></li>';
      });
      html += '</div>';
      return html;
    },
    errorMessage(error) {
      const errormessage = error.message;
      if (error.response) {
        errormessage += ': ' + error.response.data.message;
      }
      this.errors.push(errormessage);
    },
  },
});
