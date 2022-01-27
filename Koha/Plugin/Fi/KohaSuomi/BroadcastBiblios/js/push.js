const recordModal = Vue.component('recordmodal', {
  template:
    '<div id="pushRecordOpModal" class="modal fade" role="dialog">\
        <div class="modal-dialog">\
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
                <div id="spinner-wrapper" class="modal-body row text-center">\
                    <i class="fa fa-spinner fa-spin" style="font-size:36px"></i>\
                </div>\
                <div id="export-wrapper" class="modal-body">\
                </div>\
                <div id="report-wrapper" class="modal-body hidden">\
                </div>\
                <div class="modal-footer">\
                    <button type="button" @click="exportRecord()" class="btn btn-success">Vie</button>\
                    <button type="button" class="btn btn-primary">Tuo</button>\
                    <button type="button" class="btn btn-default" data-dismiss="modal">Sulje</button>\
                </div>\
            </div>\
        </div>\
        </div>',
  props: ['record', 'biblionumber', 'exportapi'],
  mounted() {},
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
      exportapi: {},
      importapi: {},
      biblionumber: 0,
      record: '',
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
    },
    getRecord() {
      axios
        .get('/api/v1/biblios/' + this.biblionumber, {
          headers: {
            Accept: 'application/marcxml+xml',
          },
        })
        .then((response) => {
          this.record = response.data;
        })
        .catch((error) => {});
    },
  },
});
