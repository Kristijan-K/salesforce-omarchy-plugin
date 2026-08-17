.pragma library

function stringValue(value) {
  return value === undefined || value === null ? "" : String(value)
}

function firstString(item, keys) {
  for (var i = 0; i < keys.length; i++) {
    var value = stringValue(item[keys[i]])
    if (value !== "") return value
  }
  return ""
}

function isSandbox(item, loginUrl) {
  if (item.isSandbox !== undefined && item.isSandbox !== null) return item.isSandbox === true
  return loginUrl.indexOf("test.salesforce.com") !== -1 || loginUrl.indexOf("sandbox") !== -1
}

function isConnectedValue(value) {
  var status = stringValue(value).toLowerCase()
  return status.indexOf("connected") !== -1 || status === "success" || status === "active"
}

function orgFromObject(item) {
  var loginUrl = firstString(item, ["instanceUrl", "loginUrl", "computedLoginUrl"])
  var username = firstString(item, ["username", "userName"])
  var alias = firstString(item, ["alias", "name", "username", "userName"])
  if (alias === "" && username === "") return null

  return {
    alias: alias || username,
    username: username || "Unknown username",
    name: firstString(item, ["name", "alias", "username", "userName"]),
    orgId: firstString(item, ["orgId", "id"]),
    loginUrl: loginUrl || "https://login.salesforce.com",
    status: isConnectedValue(firstString(item, ["connectedStatus", "connectionStatus", "status"]))
      ? "Connected"
      : "Not connected",
    isSandbox: isSandbox(item, loginUrl),
    isDefault: item.isDefaultUsername === true,
    isDevHub: item.isDevHub === true
  }
}

function collectArrays(value, result) {
  if (!value || typeof value !== "object") return
  if (Array.isArray(value)) {
    for (var i = 0; i < value.length; i++) {
      if (value[i] && typeof value[i] === "object" && !Array.isArray(value[i])) {
        var org = orgFromObject(value[i])
        if (org) result.push(org)
      }
    }
    return
  }
  for (var key in value) {
    if (Array.isArray(value[key])) collectArrays(value[key], result)
  }
}

function parseOrgs(raw) {
  var parsed
  try {
    parsed = JSON.parse(String(raw || "{}"))
  } catch (error) {
    return { orgs: [], error: "Could not parse sf org list output" }
  }

  var candidates = []
  var source = parsed.result || parsed
  var categories = ["other", "sandboxes", "scratchOrgs", "nonScratchOrgs", "devHubs", "nonTerminatedOrgInfos"]
  for (var i = 0; i < categories.length; i++) {
    if (source && Array.isArray(source[categories[i]])) collectArrays(source[categories[i]], candidates)
  }
  if (candidates.length === 0) {
    if (Array.isArray(parsed.orgs)) collectArrays(parsed.orgs, candidates)
    else if (Array.isArray(parsed)) collectArrays(parsed, candidates)
  }

  var seen = {}
  var orgs = []
  for (var j = 0; j < candidates.length; j++) {
    var candidate = candidates[j]
    var key = candidate.orgId || (candidate.username + "|" + candidate.alias)
    if (!seen[key]) {
      seen[key] = true
      orgs.push(candidate)
    }
  }
  orgs.sort(function(a, b) {
    var statusOrder = (statusIsConnected(a) ? 0 : 1) - (statusIsConnected(b) ? 0 : 1)
    if (statusOrder !== 0) return statusOrder
    var aName = String(a.alias || a.name || "").toLowerCase()
    var bName = String(b.alias || b.name || "").toLowerCase()
    var nameOrder = aName.localeCompare(bName)
    return nameOrder !== 0 ? nameOrder : String(a.username).toLowerCase().localeCompare(String(b.username).toLowerCase())
  })
  return { orgs: orgs, error: "" }
}

function statusLabel(org) {
  return statusIsConnected(org) ? "Connected" : "Not connected"
}

function statusIsConnected(org) {
  return org && String(org.status || "") === "Connected"
}

function safeName(value) {
  return String(value || "").replace(/[^A-Za-z0-9._-]/g, "_")
}

function trimUrl(value) {
  return String(value || "").trim().replace(/\/$/, "")
}

function validUrl(value) {
  return /^https?:\/\/[^\s]+$/i.test(trimUrl(value))
}
