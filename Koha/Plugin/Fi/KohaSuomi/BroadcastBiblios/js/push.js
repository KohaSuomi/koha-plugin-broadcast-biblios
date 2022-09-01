const store = new Vuex.Store({
  state: {
    loader: true,
    errors: [],
    exportApi: {},
    importApi: {},
    componentParts: [],
    biblionumber: 0,
    remoteRecord: {},
    username: '',
  },
  mutations: {
    setLoader(state, value) {
      state.loader = value;
    },
    setErrors(state, value) {
      state.errors.push(value);
    },
    clearErrors(state) {
      state.errors = [];
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
    setUsername(state, value) {
      state.username = value;
    },
  },
  actions: {
    errorMessage({ commit }, error) {
      commit('setLoader', false);
      let errormessage = error.message;
      if (error.response.data.message) {
        errormessage += ': ' + error.response.data.message;
      }
      commit('setErrors', errormessage);
    },
  },
  getters: {
    createBody: (state) => (type) => {
      const body = {
        username: state.username,
      };
      if (type == 'export') {
        body.componentparts_count = state.componentParts ? state.componentParts.length: null;
        body.componentparts = state.componentParts ? 1 : 0;
        body.interface = state.exportApi.interface;
        body.marc = state.remoteRecord.sourcerecord;
        body.source_id = state.biblionumber;
        body.target_id = state.remoteRecord.source_id
          ? state.remoteRecord.source_id
          : state.remoteRecord.target_id;
      }
      if (type == 'import') {
        body.interface = state.importApi.interface;
        body.componentparts = state.componentParts ? 1 : 0;
        body.fetch_interface = state.exportApi.interface;
        body.target_id = state.biblionumber;
        body.source_id = state.remoteRecord.source_id
          ? state.remoteRecord.source_id
          : state.remoteRecord.target_id;
        body.marc = state.remoteRecord.targetrecord;
      }
      if (type == 'componentparts') {
        body.check = state.remoteRecord.targetrecord ? 1 : 0;
        body.force = 1;
        body.parent_id = state.biblionumber;
        body.target_id = null;
        body.interface = state.exportApi.interface;
      }
      return body;
    },
    headers: (state) => (type) => {
      const auth =
        type == 'export' ? state.exportApi.token : state.importApi.token;
      return { Authorization: auth };
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
                    <div v-if="remoterecord.targetrecord" ><span class="col-sm-6"><h3>Paikallinen</h3><hr/></span><span class="col-sm-6"><h3> {{exportapi.interfaceName}} </h3><hr/></span></div>\
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
                        <td><span :inner-html.prop="report.status | translateStatus"></span><span v-if="report.errorstatus" style="color:red;"> ({{report.errorstatus}})</span></td>\
                      </tr>\
                      </tbody>\
                    </table>\
                  </div>\
                </div>\
                <div class="modal-footer">\
                    <button v-if="exportapi.type == \'export\' && showRecord" type="button" @click="sendRecord(\'export\')" class="btn btn-success" style="float:none;">Vie</button>\
                    <button v-if="remoterecord.targetrecord && showRecord" type="button" @click="sendRecord(\'import\')" class="btn btn-primary" style="float:none;">Tuo</button>\
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
    sendRecord(type) {
      this.$store.commit('setLoader', true);
      this.$store.commit('setUsername', $('.loggedinusername').html().trim());
      axios
        .post(
          this.exportapi.host + '/' + this.exportapi.basePath,
          this.$store.getters.createBody(type),
          {
            headers: this.$store.getters.headers(type),
          }
        )
        .then(() => {
          if (type == 'export') {
            this.sendComponentParts();
          } else {
            this.deleteComponentParts();
          }
        })
        .catch((error) => {
          this.$store.dispatch('errorMessage', error);
        });
    },
    async sendComponentParts() {
      const body = this.$store.getters.createBody('componentparts');
      const promises = [];
      if (this.componentparts) {
        this.componentparts.forEach((element) => {
          (body.source_id = element.biblionumber),
            (body.marc = element.marcxml);
          promises.push(
            axios
              .post(this.exportapi.host + '/' + this.exportapi.basePath, body, {
                headers: this.$store.getters.headers('export'),
              })
              .then(() => {})
              .catch((error) => {
                this.$store.dispatch('errorMessage', error);
              })
          );
        });
      }
      await Promise.all(promises).then(() => {
        this.$store.commit('setLoader', false);
        this.getReports();
      });
    },
    async deleteComponentParts() {
      const promises = [];
      if (this.componentparts) {
        this.componentparts.forEach((element) => {
          promises.push(
            axios
              .delete('/api/v1/biblios/' + element.biblionumber)
              .then(() => {})
              .catch((error) => {
                this.$store.dispatch('errorMessage', error);
              })
          );
        });
      }
      await Promise.all(promises).then(() => {
        this.$store.commit('setLoader', false);
        this.getReports();
      });
    },
    getRecords() {
      this.showRecord = true;
      this.$parent.searchRemoteRecord();
    },
    getReports() {
      this.$store.commit('setLoader', true);
      this.$store.commit('clearErrors');
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
          this.$store.dispatch('errorMessage', error);
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
        interfaceName: e.target.textContent,
        interface: e.target.getAttribute('data-interface'),
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
          store.dispatch('errorMessage', error);
        });
    },
    searchRemoteRecord() {
      store.commit('setLoader', true);
      store.commit('clearErrors');
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
          store.dispatch('errorMessage', error);
        });
    },
  },
});
