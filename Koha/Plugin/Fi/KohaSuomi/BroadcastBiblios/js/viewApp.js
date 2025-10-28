import * as recordParser from './helpers/recordParser.js';
import { t, setLang } from './helpers/translations.js';

// Set language based on browser or user preference
const browserLang = (pageLang || navigator.language || navigator.userLanguage || 'en').substring(0,2);
setLang(['en', 'fi', 'sv'].includes(browserLang) ? browserLang : 'en');

new Vue({
  el: '#viewApp',
  created() {
    this.fetchQueue();
  },
  data: {
    results: [],
    errors: [],
    status: 'pending',
    isActive: false,
    page: 1,
    limit: 50,
    pages: 1,
    startCount: 1,
    endPage: 11,
    lastPage: 0,
    biblioId: null,
    showCheckActive: false,
    activation: {},
    showModifyActivation: false,
    identifier_field: '',
    identifier: '',
    blocked: false,
    success: '',
    showLoader: false,
  },
  methods: {
    fetchQueue() {
      this.showLoader = true;
      this.errors = [];
      this.results = [];
      axios
        .get('/api/v1/contrib/kohasuomi/broadcast/queue', {
          params: { status: this.status, page: this.page, limit: this.limit },
        })
        .then((response) => {
          this.results = response.data.results;
          this.pages = Math.ceil(response.data.count / this.limit);
          if (this.pages == 0) {
            this.pages = 1;
          }
          this.activate();
          this.showLoader = false;
        })
        .catch((error) => {
          if (!error.response.data.error) {
            this.errors.push(error.message);
          }
          this.errors.push(error.response.data.error);
        });
    },
    getQueue() {
      this.showLoader = true;
      this.errors = [];
      this.results = [];
      this.page = 1;
      axios
        .get('/api/v1/contrib/kohasuomi/broadcast/queue', {
          params: {
            status: this.status,
            page: this.page,
            limit: this.limit,
            biblio_id: this.biblioId,
          },
        })
        .then((response) => {
          this.results = response.data.results;
          this.pages = Math.ceil(response.data.count / this.limit);
          if (this.pages == 0) {
            this.pages = 1;
          }
          this.activate();
          this.showLoader = false;
        })
        .catch((error) => {
          this.errors.push(error.response.data.error);
        });
    },
    getActiveRecord(e) {
      e.preventDefault();
      this.errors = [];
      axios
        .get('/api/v1/contrib/kohasuomi/broadcast/biblios/active/'+this.biblioId)
        .then((response) => {
          this.activation = response.data;
        })
        .catch((error) => {
          this.errors.push(error.response.data.error);
        });
    },
    updateActiveRecord(e) {
      this.success = '';
      this.errors = [];
      if (
        this.identifier_field == '003|001' &&
        !this.identifier.includes('|')
      ) {
        this.errors.push(
          t('Standardinumero ei ole oikeassa muodossa, erota kentät putkella -> 003|001')
        );
      }
      if (!this.errors.length) {
        let blocked = this.blocked ? 1 : 0;
        axios
          .put('/api/v1/contrib/kohasuomi/broadcast/biblios/active/' + this.activation.biblionumber, {
            identifier_field: this.identifier_field,
            identifier: this.identifier,
            blocked: blocked,
          })
          .then(() => {
            this.success =
              t('Tietue ') + this.activation.biblionumber + ' ' + t('päivitetty!');
            this.getActiveRecord(e);
            this.showModifyActivation = false;
          })
          .catch((error) => {
            this.errors.push(error.response.data.error);
          });
      }
    },
    changeStatus(status, event) {
      event.preventDefault();
      this.showCheckActive = false;
      $('.nav-link').removeClass('active');
      $(event.target).addClass('active');
      this.results = [];
      this.status = status;
      this.page = 1;
      this.biblioId = '';
      this.fetchQueue();
    },
    checkActivation(event) {
      $('.nav-link').removeClass('active');
      $(event.target).addClass('active');
      this.results = [];
      this.pages = 1;
      this.biblioId = '';
      this.showCheckActive = true;
    },
    modifyActivation(e) {
      e.preventDefault();
      this.showModifyActivation = true;
      this.identifier = this.activation.identifier;
      this.identifier_field = this.activation.identifier_field;
      this.blocked = this.activation.blocked == 1 ? true : false;
    },
    closeUpdate() {
      this.showModifyActivation = false;
    },
    changePage(e, page) {
      e.preventDefault();
      if (page < 1) {
        page = 1;
      }
      if (page > this.pages) {
        page = this.pages;
      }
      this.page = page;
      if (this.page == this.endPage) {
        this.startCount = this.page;
        this.endPage = this.endPage + 10;
        this.lastPage = this.page;
      }
      if (this.page < this.lastPage) {
        this.startCount = this.page - 10;
        this.endPage = this.lastPage;
        this.lastPage = this.lastPage - 10;
      }
      this.fetchQueue();
    },
    activate() {
      $('.page-link').removeClass('bg-primary text-white');
      $('[data-current=' + this.page + ']').addClass('bg-primary text-white');
    },
    pageHide(page) {
      if (this.pages > 5) {
        if (this.endPage <= page && this.startCount < page) {
          return true;
        }
        if (this.endPage >= page && this.startCount > page) {
          return true;
        }
      }
    },
  },
  filters: {
    moment: function (date) {
      return moment(date).locale('fi').format('D.M.Y H:mm:ss');
    },
    blocked: function (blocked) {
      if (blocked) {
        return t('Kyllä');
      } else {
        return t('Ei');
      }
    }
  },
});

Vue.component('result-list', {
  template: '#list-items',
  data() {
    return {
      active: false,
      notifyfields: '',
      showRecord: false,
      showComponentPart: 0,
      clicked: false,
    };
  },
  mounted() {
    if (this.result.diff) {
      this.notify();
    }
  },
  methods: {
    getRecord(e) {
      e.preventDefault();
      $('#modalWrapper').find('#recordModal').remove();
      var html = $(
        '<div id="recordModal" class="modal fade" role="dialog">\
                      <div class="modal-dialog modal-lg">\
                          <div class="modal-content">\
                              <div class="modal-header">\
                                  <h5 class="modal-title">' + t('Muutokset') + '</h5>\
                                  <button type="button" class="close" data-dismiss="modal" aria-label="Close">\
                                      <span aria-hidden="true">&times;</span>\
                                  </button>\
                              </div>\
                              <div id="recordWrapper" class="modal-body">\
                              </div>\
                              <div class="modal-footer">\
                                  <button type="button" class="btn btn-default" data-dismiss="modal">' + t('Sulje') + '</button>\
                              </div>\
                          </div>\
                      </div>\
                  </div>'
      );
      $('#modalWrapper').append(html);
      var source = recordParser.parseDiff(this.result.diff);
      $('#recordModal')
        .find('#recordWrapper')
        .append($('<div class="container">' + source + '</div>'));
      $('#recordModal').modal('toggle');
      this.active = false;
      this.clicked = true;
    },
    toggleShowRecord(e) {
      e.preventDefault();
      this.showRecord = !this.showRecord;
    },
    toggleShowComponentPart(e, part) {
      e.preventDefault();
      if (this.showComponentPart == part) {
        part = 0;
      }
      this.showComponentPart = part;
    },
    notify() {
      let record = this.result.diff;
      let tags = Object.keys(record);
      let notifyFieldsArr = notifyFields.split(',');
      tags.sort();
      tags.forEach((element) => {
        let obj = record[element];
        notifyFieldsArr.forEach((field) => {
          let tag = field.substring(0, 3);
          let code = field.substring(3);
          if (tag == element) {
            if (code) {
              if (obj.new) {
                obj.new.forEach((newtag) => {
                  newtag.subfields.forEach((newsub) => {
                    if (
                      code == newsub.code &&
                      !this.notifyfields.includes(tag + code + '!')
                    ) {
                      this.notifyfields += tag + code + '! ';
                    }
                  });
                });
              } else if (obj.add) {
                obj.add.forEach((addtag) => {
                  addtag.subfields.forEach((addsub) => {
                    if (
                      code == addsub.code &&
                      !this.notifyfields.includes(tag + code + '!')
                    ) {
                      this.notifyfields += tag + code + '! ';
                    }
                  });
                });
              }
            } else {
              if (element == '000') {
                if (
                  obj.old &&
                  obj.new &&
                  obj.old[0].value.charAt(17) != obj.new[0].value.charAt(17)
                ) {
                  this.notifyfields += element + '/17! ';
                }
              } else {
                this.notifyfields += element + '! ';
              }
            }
          }
        });
      });
    },
  },
  filters: {
    moment: function (date) {
      return moment(date).locale('fi').format('D.M.Y H:mm:ss');
    },
    record: function (record) {
      return recordParser.recordAsHTML(record);
    },
    title: function (record) {
      return recordParser.recordTitle(record);
    },
    author: function (record) {
      return recordParser.recordAuthor(record);
    },
    itemType: function (record) {
      return recordParser.recordItemType(record);
    },
    transfer: function (type) {
      if (type == 'import') {
        return t('Tuonti');
      } else {
        return t('Vienti');
      }
    },
  },
  props: ['result'],
});