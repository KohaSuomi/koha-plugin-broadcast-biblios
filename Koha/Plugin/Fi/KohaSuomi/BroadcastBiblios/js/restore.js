$(document).ready(function () {
    if (window.location.pathname == "/cgi-bin/koha/tools/viewlog.pl") {
        var logstElement = document.getElementById("logst");
        if (logstElement) {
            var rows = logstElement.querySelectorAll("tr");
            rows.forEach(function(row) {
                if (row.cells[2].textContent.includes("Catalog") && row.cells[3].textContent.includes("Modify")) {
                    var loginfoRow = row.querySelector(".loginfo");
                    if (loginfoRow && loginfoRow.textContent.startsWith("biblio")) {
                        let actionId = loginfoRow.id.match(/\d+/g)[0];
                        var restoreButton = document.createElement("button");
                        restoreButton.textContent = "Palauta";
                        restoreButton.onclick = function() {
                            sendRequest(actionId, row.cells[0].textContent);
                        };
                        loginfoRow.appendChild(document.createElement("br"));
                        loginfoRow.appendChild(restoreButton);
                    }
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



  