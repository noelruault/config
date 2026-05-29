"use strict"

const ping = "pong"
export function doPing() {return ping}

const dataMap = new Map([
	["name", "Map"],
	[true, "I'm a map"],
])
export function showMap() {return dataMap}

const dataObject = {name:  "Object", works: true}
export function showObject() {return dataObject}
