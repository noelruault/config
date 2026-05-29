"use strict" // directive that will disallow undeclared variables

const DEBUG = true

// Change js-status to "enabled" to reflect that the script is online
function updateJSStatus() {
	const javascriptStatus = document.getElementById("status-js")
	javascriptStatus.style.color = "green";
	javascriptStatus.innerHTML = "online";
}

DEBUG ? updateJSStatus() : document.getElementById("debug-stats").hidden = true
