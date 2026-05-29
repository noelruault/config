"use strict"

const DEBUG = true

// Change js-status to "enabled" to reflect that the script is online
function updateJSStatus() {
	const javascriptStatus = document.getElementById("status-js")
	javascriptStatus.style.color = "green"
	javascriptStatus.innerHTML = "online"
}

DEBUG ? updateJSStatus() : document.getElementById("debug-stats").hidden = true

const ping = "pong"
export function doPing() {return ping}

const dataMap = new Map([
	["name", "Map"],
	[true, "I'm a map"],
])
export function showMap() {return dataMap}

const dataObject = {name:  "Object", works: true}
export function showObject() {return dataObject}
