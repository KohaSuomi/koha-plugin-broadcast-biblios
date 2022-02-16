const recordModal = Vue.component('recordmodal', {
  template:
    '<div id="pushRecordOpModal" class="modal fade" role="dialog">\
        <div class="modal-dialog" :class="{\'modal-lg\': remoterecord.targetrecord}">\
            <div class="modal-content">\
                <div class="modal-header">\
                    <ul class="nav nav-pills">\
                        <li class="nav-item">\
                            <a id="exporter" @click="getRecords()" class="nav-link" style="background-color:#007bff; color:#fff;" href="#">Siirto<i class="fa fa-refresh" style="margin-left:7px;"></i></a>\
                        </li>\
                        <li class="nav-item">\
                            <a id="report" class="nav-link" href="#" @click="getReports()">Tapahtumat<i class="hidden fa fa-refresh" style="margin-left:7px;"></i></a>\
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
                <div v-if="showRecord" id="exportRecordWrapper" class="modal-body">\
                  <div id="exportRecord">\
                    <div v-if="remoterecord.targetrecord" ><span class="col-sm-6"><h3>Paikallinen</h3><hr/></span><span class="col-sm-6"><h3> {{exportapi.interface}} </h3><hr/></span></div>\
                    <div class="col-sm-6" v-html="parseRecord(remoterecord.sourcerecord)"></div>\
                    <div v-if="remoterecord.targetrecord" class="col-sm-6" v-html="parseRecord(remoterecord.targetrecord)"></div>\
                  </div>\
                </div>\
                <div v-else id="exportReportWrapper" class="modal-body">\
                  <div class="table-responsive">\
                    <table class="table table-striped table-sm">\
                      <thead>\
                        <tr>\
                          <th>Tapahtuma</th>\
                          <th>Aika</th>\
                          <th>Tila</th>\
                        </tr>\
                      </thead>\
                      <tbody><tr v-for="(report, index) in reports">\
                        <td>{{report.target_id | exportType}}</td>\
                        <td>{{report.timestamp | moment}}</td>\
                        <td :inner-html.prop="report.status | translateStatus"></td>\
                      </tr>\
                      </tbody>\
                    </table>\
                  </div>\
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
    'remoterecord',
    'componentparts',
    'errors',
    'biblionumber',
    'exportapi',
    'importapi',
  ],
  data() {
    return {
      loader: false,
      showRecord: true,
      username: '',
      reports: [],
    };
  },
  methods: {
    exportRecord() {
      this.username = $('.loggedinusername').html().trim();
      const body = {
        username: this.username,
        source_id: this.biblionumber,
        marc: this.remoterecord.sourcerecord,
        interface: this.exportapi.interface,
        componentparts_count: this.componentparts.length,
      };
      console.log(body);
      const headers = { Authorization: this.exportapi.token };
      axios
        .post(this.exportapi.host + '/' + this.exportapi.basePath, body, {
          headers,
        })
        .then(() => {
          this.exportComponentParts();
        })
        .catch((error) => {
          console.log(error);
        });
    },
    exportComponentParts() {
      const body = {
        interface: this.exportapi.interface,
        check: this.remoterecord.targetrecord ? true : false,
        username: this.username,
        target_id: null,
        parent_id: this.biblionumber,
        force: 1,
      };
      const headers = { Authorization: this.exportapi.token };
      this.componentparts.forEach((element) => {
        (body.source_id = element.biblionumber), (body.marc = element.marcxml);
        axios
          .post(this.exportapi.host + '/' + this.exportapi.basePath, body, {
            headers,
          })
          .then(() => {})
          .catch((error) => {
            console.log(error);
          });
      });
    },
    getRecords() {
      this.showRecord = true;
      this.$parent.searchRemoteRecord();
    },
    getReports() {
      this.showRecord = false;
      const headers = { Authorization: this.exportapi.token };
      axios
        .get(
          this.exportapi.host +
            '/' +
            this.exportapi.reportPath +
            '/' +
            this.biblionumber,
          {
            headers,
          }
        )
        .then((response) => {
          this.reports = response.data;
        })
        .catch((error) => {
          console.log(error);
        });
    },
    parseRecord(record) {
      if (record) {
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
      }
    },
  },
  filters: {
    exportType: function (value) {
      if (value == this.biblionumber) {
        return 'tuonti (päivitys)';
      } else {
        if (value != '' && value != null) {
          return 'vienti (päivitys)';
        } else {
          return 'vienti (uusi)';
        }
      }
    },
    translateStatus: function (value) {
      if (value == 'pending' || value == 'waiting') {
        return '<i style="color:orange;">Odottaa</i>';
      }
      if (value == 'success') {
        return '<i style="color:green;">Onnistui</i>';
      }
      if (value == 'failed') {
        return '<i style="color:red;">Epäonnistui</i>';
      }
    },
    moment: function (date) {
      return moment(date).locale('fi').format('D.M.Y H:mm:ss');
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
      remoterecord: {},
      componentparts: [],
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
              Accept: 'application/json',
            },
          }
        )
        .then((response) => {
          this.record = response.data.biblio.marcxml;
          this.componentparts = response.data.componentparts;
        })
        .catch((error) => {
          this.errorMessage(error);
        });
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
          this.remoterecord = response.data;
        })
        .catch((error) => {
          this.errorMessage(error);
        });
    },
    errorMessage(error) {
      let errormessage = error.message;
      if (error.response) {
        errormessage += ': ' + error.response.data.message;
      }
      this.errors.push(errormessage);
    },
  },
});
