// Importing Hono and dependencies
import { Hono } from "hono"
import { doPing, showMap, showObject } from "./server/base.js"
import { basicAuth } from "hono/basic-auth"

// Initializing Hono
const app = new Hono()

app.get("/status", (c) => {
	return c.json({
		status:     "ok",
		version:    "0.0.1",
		serverTime: new Date().toISOString()
	})
})

// --------- Testing the base functions --------- //

const nameMap = new Map([
	[1, ["Hey","!"]],
	[2, ["This works", "!"]]
])

// Defining a route with Hono
app.get("/api", (c) => {
	return c.json({
		baseping:   doPing(),
		basemap:    Object.fromEntries(showMap()),
		baseobject: showObject(),
		selfdata:   Object.fromEntries(nameMap)
	})
})

// :/posts/12?page=34
app.get("/posts/:id", (c) => {
	const page = c.req.query("page")
	const id = c.req.param("id")
	c.header("X-Message", "Hi!")
	return c.text(`You want see ${page} of ${id}`)
})


// Basic Auth
const authorizedUsers = [
	{ username: "admin2", password: "secret" },
	{ sername: "admin3", password: "secret" }
]
app.use( "/admin/*", basicAuth(...authorizedUsers))
app.get("/admin", (c) => {
	return c.text("You are authorized!")
})

// Exporting the initialized Hono app
export default app
