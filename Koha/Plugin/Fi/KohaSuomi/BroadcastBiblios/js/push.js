const store = new Vuex.Store({
  state: {
    loader: true,
    errors: [],
    exportApi: {},
    importApi: {},
    componentParts: [],
    biblionumber: 0,
    remoteRecord: {},
  },
  mutations: {
    setLoader(state, value) {
      state.loader = value;
    },
    setErrors(state, value) {
      state.errors.push(value);
    },
    setExportApi(state, value) {
      state.exportApi = value;
    },
    setImportApi(state, value) {
      state.importApi = value;
    },
    setComponentParts(state, value) {
      state.componentParts = value;
    },
    setBiblionumber(state, value) {
      state.biblionumber = value;
    },
    setRemoteRecord(state, value) {
      state.remoteRecord = value;
    },
  },
});

const recordModal = Vue.component('recordmodal', {
  template:
    '<div id="pushRecordOpModal" class="modal fade" role="dialog">\
        <div class="modal-dialog" :class="{\'modal-lg\': remoterecord.targetrecord}">\
            <div class="modal-content">\
                <div class="modal-header">\
                    <ul class="nav nav-pills">\
                        <li class="nav-item">\
                            <a id="exporter" @click="getRecords()" class="nav-link" :style="showRecord ? activeLinkStyle : null" href="#">Siirto<i :class="{hidden : !showRecord}" class="fa fa-refresh" style="margin-left:7px;"></i></a>\
                        </li>\
                        <li class="nav-item">\
                            <a id="report" class="nav-link" href="#" @click="getReports()" :style="showRecord ? null : activeLinkStyle">Tapahtumat<i :class="{hidden : showRecord}" class="fa fa-refresh" style="margin-left:7px;"></i></a>\
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
  data() {
    return {
      showRecord: true,
      username: '',
      reports: [],
      activeLinkStyle: {
        'background-color': '#007bff',
        color: '#fff',
      },
    };
  },
  computed: {
    loader() {
      return this.$store.state.loader;
    },
    errors() {
      return this.$store.state.errors;
    },
    exportapi() {
      return this.$store.state.exportApi;
    },
    importapi() {
      return this.$store.state.importApi;
    },
    componentparts() {
      return this.$store.state.componentParts;
    },
    biblionumber() {
      return this.$store.state.biblionumber;
    },
    remoterecord() {
      return this.$store.state.remoteRecord;
    },
  },
  methods: {
    exportRecord() {
      this.$store.commit('setLoader', true);
      this.username = $('.loggedinusername').html().trim();
      const body = {
        username: this.username,
        source_id: this.biblionumber,
        marc: this.remoterecord.sourcerecord,
        interface: this.exportapi.interface,
        componentparts_count: this.componentparts.length,
      };
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
    async exportComponentParts() {
      const body = {
        interface: this.exportapi.interface,
        check: this.remoterecord.targetrecord ? true : false,
        username: this.username,
        target_id: null,
        parent_id: this.biblionumber,
        force: 1,
      };
      const headers = { Authorization: this.exportapi.token };
      const promises = [];
      this.componentparts.forEach((element) => {
        (body.source_id = element.biblionumber), (body.marc = element.marcxml);
        promises.push(
          axios
            .post(this.exportapi.host + '/' + this.exportapi.basePath, body, {
              headers,
            })
            .then(() => {})
            .catch((error) => {
              console.log(error);
            })
        );
      });
      await Promise.all(promises).then(() => {
        this.$store.commit('setLoader', false);
      });
    },
    getRecords() {
      this.showRecord = true;
      this.$parent.searchRemoteRecord();
    },
    getReports() {
      this.$store.commit('setLoader', true);
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
          this.$store.commit('setLoader', false);
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
  store: store,
  components: {
    recordModal,
  },
  data() {
    return {
      record: '',
    };
  },
  created() {
    const interface = document.getElementById('importInterface');
    const importapi = {
      interface: interface.textContent,
      host: interface.getAttribute('data-host'),
      basePath: interface.getAttribute('data-basepath'),
      searchPath: interface.getAttribute('data-searchpath'),
      reportPath: interface.getAttribute('data-reportpath'),
      token: interface.getAttribute('data-token'),
      type: interface.getAttribute('data-type'),
    };
    store.commit('setImportApi', importapi);
    const queryString = window.location.search;
    const urlParams = new URLSearchParams(queryString);
    store.commit('setBiblionumber', urlParams.get('biblionumber'));
    this.getRecord();
  },
  computed: {
    exportapi() {
      return store.state.exportApi;
    },
    biblionumber() {
      return store.state.biblionumber;
    },
  },
  methods: {
    openModal(e) {
      e.preventDefault();
      const exportapi = {
        interface: e.target.textContent,
        host: e.target.getAttribute('data-host'),
        basePath: e.target.getAttribute('data-basepath'),
        searchPath: e.target.getAttribute('data-searchpath'),
        reportPath: e.target.getAttribute('data-reportpath'),
        token: e.target.getAttribute('data-token'),
        type: e.target.getAttribute('data-type'),
      };
      store.commit('setExportApi', exportapi);
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
          store.commit('setComponentParts', response.data.componentparts);
        })
        .catch((error) => {
          this.errorMessage(error);
        });
    },
    searchRemoteRecord() {
      store.commit('setLoader', true);
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
          store.commit('setRemoteRecord', response.data);
          store.commit('setLoader', false);
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
      store.commit('setErrors', errormessage);
    },
  },
});
