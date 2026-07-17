"use strict";
const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const { parsePairingParameters, consumePairingParameters } = require("../static/pairing_params.js");

test("reads PIN and all valid player choices from QR URL", () => {
  for (const player of ["auto", "1", "2"]) {
    assert.deepEqual(parsePairingParameters(`http://192.168.1.2:8765/?pin=123456&player=${player}`), {
      hasParameters: true, pin: "123456", player, playerValid: true,
    });
  }
});

test("invalid player and PIN are not accepted", () => {
  const params = parsePairingParameters("http://host/?pin=bad&player=3");
  assert.equal(params.pin, "");
  assert.equal(params.player, "auto");
  assert.equal(params.playerValid, false);
});

test("PIN is removed from browser address and remains only in memory", () => {
  const calls = [];
  const fakeWindow = {
    location: { href: "http://host/?pin=123456&player=2", pathname: "/", hash: "" },
    history: { replaceState: (...args) => calls.push(args) },
  };
  const params = consumePairingParameters(fakeWindow);
  assert.equal(params.pin, "123456");
  assert.deepEqual(calls, [[null, "", "/"]]);
});

test("pairing remains confirmation-based and never uses localStorage", () => {
  const app = fs.readFileSync("static/app.js", "utf8");
  const html = fs.readFileSync("static/index.html", "utf8");
  assert.doesNotMatch(app, /localStorage/);
  assert.match(html, /type="submit">CONECTAR/);
  assert.doesNotMatch(app, /connect\(pairingFromUrl/);
});
