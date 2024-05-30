$(document).ready(function () {
    if (window.location.pathname == "/cgi-bin/koha/tools/viewlog.pl") {
        var logstElement = document.getElementById("logst");
        if (logstElement) {
            var rows = logstElement.querySelectorAll("tr");
            rows.forEach(function(row) {
                let restoreButton = document.createElement("button");
                var userLang = navigator.language || navigator.userLanguage; 
                if (userLang == 'en-US'){
                    restoreButton.textContent = "Restore";
                } else if (userLang == 'fi-FI'){
                    restoreButton.textContent = "Palauta";
                } else if (userLang == 'sv-SE'){
                    restoreButton.textContent = "Återställ";
                }
                let loginfoRow = row.querySelector(".loginfo");
                if (loginfoRow && /BEFORE=>/.test(loginfoRow.textContent)) {
                    let actionId = loginfoRow.id.match(/\d+/g)[0];
                    restoreButton.onclick = function() {
                        sendRequest(actionId, row.cells[0].textContent);
                    };
                    loginfoRow.appendChild(document.createElement("br"));
                    loginfoRow.appendChild(restoreButton);
                }
                
            });
        }
    }
});

function sendRequest(actionId, timestamp) {
    // Make an AJAX request to the REST API endpoint
    $.ajax({
        url: "/api/v1/contrib/kohasuomi/biblios/restore/" + actionId,
        method: "POST",
        success: function(response) {
            // Handle the response from the server
            alert("Tietue on palautettu ajalle " + timestamp);
            window.location.href = "/cgi-bin/koha/catalogue/detail.pl?biblionumber=" + response.biblio_id;

        },
        error: function(xhr, status, error) {
            // Handle any errors that occur during the request
            alert("Tapahtui virhe: "+ error);
        }
    });
}



  