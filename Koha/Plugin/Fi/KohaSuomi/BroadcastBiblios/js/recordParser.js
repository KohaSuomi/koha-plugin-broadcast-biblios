export const recordAsHTML = (record) => {
    let html = '<div>';
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
};

export const recordTitle = (record) => {
    let title = '';
    record.fields.forEach(function (v, i, a) {
        if (v.tag == '245') {
            if (v.subfields) {
                v.subfields.forEach(function (v, i, a) {
                if (v.code == 'a') {
                    title = v.value;
                }
                if (v.code == 'b') {
                    title += ' ' + v.value;
                } 
                if (v.code == 'n') {
                    title += ' ' + v.value;
                } 
                if (v.code == 'p') {
                    title += ' ' + v.value;
                }
                });
            }
        }
    });
    return title;
}

export const recordAuthor = (record) => {
    let author = '';
    record.fields.forEach(function (v, i, a) {
        if (v.tag == '100') {
            if (v.subfields) {
                v.subfields.forEach(function (v, i, a) {
                if (v.code == 'a') {
                    author = v.value;
                }
                });
            }
        } else if (v.tag == '110') {
            if (v.subfields) {
                v.subfields.forEach(function (v, i, a) {
                if (v.code == 'a') {
                    author = v.value;
                }
                });
            }
        } else if (v.tag == '111') {
            if (v.subfields) {
                v.subfields.forEach(function (v, i, a) {
                if (v.code == 'a') {
                    author = v.value;
                }
                });
            }
        }
    });
    return author;
}

export const recordEncodingLevel = (record) => {
    return record.leader.charAt(17);
}

export const recordStatus = (record) => {
    return record.leader.charAt(5);
}

export const recordItemType = (record) => {
    let itemType = '';
    record.fields.forEach(function (v, i, a) {
        if (v.tag == '942') {
            if (v.subfields) {
                v.subfields.forEach(function (v, i, a) {
                if (v.code == 'c') {
                    itemType = v.value;
                }
                });
            }
        }
    });
    return itemType;
}

export const parseDiff = (record) => {
    let tags = Object.keys(record);
    let html = '<div class="row pb-2">';
    html += '<div class="col-md-6"><b>Vanhat</b></div>';
    html += '<div class="col-md-6"><b>Uudet</b></div>';
    html += '</div>';
    tags.sort();
    tags.forEach((element) => {
        var obj = record[element];
        html += '<div class="row">';
        html += '<div class="col-md-6" style="overflow:hidden;">';
        if (obj.remove) {
        if (element != '999' && element != '942' && element != '952') {
            obj.remove.forEach((removetag) => {
            html += '<div class="col-xs-6">';
            if (removetag.subfields) {
                removetag.subfields.forEach((removesub) => {
                html += '<div class="text-danger"><b>' + element;
                if (removetag.ind1) {
                    html += ' ' + removetag.ind1;
                }
                if (removetag.ind2) {
                    html += ' ' + removetag.ind2;
                }
                html +=
                    ' _' + removesub.code + '</b>' + removesub.value + '</div>';
                });
            } else {
                html += '<b>' + element + '</b> ' + removetag.value;
            }
            html += '</div>';
            });
        }
        }
        if (obj.old) {
        if (element != '999' && element != '942' && element != '952') {
            obj.old.forEach((oldtag) => {
            if (oldtag) {
                html += '<div class="col-xs-6">';
                if (oldtag.subfields) {
                oldtag.subfields.forEach((oldsub) => {
                    html += '<div><b>' + element;
                    if (oldtag.ind1) {
                    html += ' ' + oldtag.ind1;
                    }
                    if (oldtag.ind2) {
                    html += ' ' + oldtag.ind2;
                    }
                    html += ' _' + oldsub.code + '</b>' + oldsub.value + '</div>';
                });
                } else {
                html += '<b>' + element + '</b> ' + oldtag.value;
                }
                html += '</div>';
            }
            });
        }
        }
        html += '</div>';
        html += '<div class="col-md-6" style="overflow:hidden;">';
        if (obj.add) {
        if (element != '999' && element != '942' && element != '952') {
            obj.add.forEach((addtag) => {
            html += '<div class="col-xs-6">';
            if (addtag.subfields) {
                addtag.subfields.forEach((addsub) => {
                html += '<div class="text-success"><b>' + element;
                if (addtag.ind1) {
                    html += ' ' + addtag.ind1;
                }
                if (addtag.ind2) {
                    html += ' ' + addtag.ind2;
                }
                html += ' _' + addsub.code + '</b>' + addsub.value + '</div>';
                });
            } else {
                html += '<b>' + element + '</b> ' + addtag.value;
            }
            html += '</div>';
            });
        }
        }
        if (obj.new) {
        if (element != '999' && element != '942' && element != '952') {
            obj.new.forEach((newtag) => {
            html += '<div class="col-xs-6">';
            if (newtag.subfields) {
                newtag.subfields.forEach((newsub) => {
                html += '<div><b>' + element;
                if (newtag.ind1) {
                    html += ' ' + newtag.ind1;
                }
                if (newtag.ind2) {
                    html += ' ' + newtag.ind2;
                }
                html += ' _' + newsub.code + '</b>' + newsub.value + '</div>';
                });
            } else {
                html += '<b>' + element + '</b> ' + newtag.value;
            }
            html += '</div>';
            });
        }
        }
        html += '</div>';
    
        html += '</div>';
    });
    
    return html;
};