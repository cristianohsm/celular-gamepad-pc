"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { XInputStateTransmitter, neutralState } = require("./static/xinput_state.js");

class FakeClock {
  constructor() { this.time = 0; this.nextId = 1; this.timers = new Map(); }
  now = () => this.time;
  setTimeout = (callback, delay) => {
    const id = this.nextId++;
    this.timers.set(id, { at: this.time + delay, callback });
    return id;
  };
  clearTimeout = (id) => this.timers.delete(id);
  advance(milliseconds) {
    const target = this.time + milliseconds;
    while (true) {
      const pending = [...this.timers.entries()].sort((a, b) => a[1].at - b[1].at || a[0] - b[0])[0];
      if (!pending || pending[1].at > target) break;
      this.time = pending[1].at;
      this.timers.delete(pending[0]);
      pending[1].callback();
    }
    this.time = target;
  }
}

function setup(player = 1, outputMode = "xinput") {
  const clock = new FakeClock();
  const sent = [];
  let writable = true;
  const transmitter = new XInputStateTransmitter({
    send: (payload) => { if (!writable) return false; sent.push({ at: clock.time, payload }); return true; },
    now: clock.now,
    timestamp: clock.now,
    setTimeoutFn: clock.setTimeout,
    clearTimeoutFn: clock.clearTimeout,
    refreshMs: 200,
    maxHz: 60,
  });
  transmitter.setSession({ authenticated: true, outputMode, player });
  return { clock, sent, transmitter, setWritable: (value) => { writable = value; } };
}

function heldState(group, name, value = true) {
  const state = neutralState();
  state[group][name] = value;
  return state;
}

function assertHeldForTwoSeconds(group, name, value = true) {
  const { clock, sent, transmitter } = setup();
  transmitter.update(heldState(group, name, value));
  clock.advance(2100);
  assert.ok(sent.length >= 11);
  assert.ok(sent.every((item) => item.payload[group][name] === value));
  for (let index = 1; index < sent.length; index += 1) assert.ok(sent[index].at - sent[index - 1].at < 750);
}

test("D-pad Right held for over two seconds stays active", () => assertHeldForTwoSeconds("dpad", "right"));
test("D-pad Left held for over two seconds stays active", () => assertHeldForTwoSeconds("dpad", "left"));
test("button A held for over two seconds stays active", () => assertHeldForTwoSeconds("buttons", "a"));

test("LT and RT refresh with unchanged values", () => {
  const { clock, sent, transmitter } = setup();
  const state = neutralState(); state.axes.lt = 0.4; state.axes.rt = 0.8;
  transmitter.update(state); clock.advance(2100);
  assert.ok(sent.length >= 11);
  assert.ok(sent.every((item) => item.payload.axes.lt === 0.4 && item.payload.axes.rt === 0.8));
});

test("held analog stick stays away from center", () => {
  const { clock, sent, transmitter } = setup();
  const state = neutralState(); state.axes.lx = 0.65; state.axes.ly = -0.35;
  transmitter.update(state); clock.advance(2100);
  assert.ok(sent.length >= 11);
  assert.ok(sent.every((item) => item.payload.axes.lx === 0.65 && item.payload.axes.ly === -0.35));
});

test("release sends neutral state immediately and stops refresh", () => {
  const { clock, sent, transmitter } = setup();
  transmitter.update(heldState("buttons", "a")); clock.advance(5);
  const releasedAt = clock.time; transmitter.update(neutralState(), true);
  assert.equal(sent.at(-1).at, releasedAt);
  assert.equal(sent.at(-1).payload.buttons.a, false);
  const count = sent.length; clock.advance(2000); assert.equal(sent.length, count);
});

test("disconnect sends neutral state and cancels refresh", () => {
  const { clock, sent, transmitter } = setup();
  transmitter.update(heldState("dpad", "right")); clock.advance(400);
  const disconnectedAt = clock.time;
  transmitter.deactivate(true);
  assert.ok(sent.at(-1).at - disconnectedAt <= 750);
  assert.equal(sent.at(-1).payload.dpad.right, false);
  const count = sent.length; clock.advance(1000); assert.equal(sent.length, count);
});

test("players refresh independently without leakage", () => {
  const one = setup(1); const two = setup(2);
  one.transmitter.update(heldState("buttons", "a"));
  two.transmitter.update(heldState("buttons", "b"));
  one.clock.advance(2100); two.clock.advance(2100);
  assert.ok(one.sent.every((item) => item.payload.player === 1 && item.payload.buttons.a && !item.payload.buttons.b));
  assert.ok(two.sent.every((item) => item.payload.player === 2 && item.payload.buttons.b && !item.payload.buttons.a));
});

test("refresh sequences are strictly increasing", () => {
  const { clock, sent, transmitter } = setup();
  transmitter.update(heldState("dpad", "right")); clock.advance(2100);
  assert.deepEqual(sent.map((item) => item.payload.sequence), sent.map((_, index) => index + 1));
});

test("neutral state does not generate continuous traffic", () => {
  const { clock, sent, transmitter } = setup();
  transmitter.update(neutralState(), true); const count = sent.length;
  clock.advance(3000); assert.equal(sent.length, count);
});

test("new authenticated session restarts at sequence one", () => {
  const { clock, sent, transmitter } = setup();
  transmitter.update(heldState("buttons", "a")); clock.advance(400);
  transmitter.deactivate(true);
  transmitter.setSession({ authenticated: true, outputMode: "xinput", player: 1 });
  transmitter.update(heldState("buttons", "b"));
  assert.equal(sent.at(-1).payload.sequence, 1);
});

test("keyboard mode remains silent and compatible", () => {
  const { clock, sent, transmitter } = setup(1, "keyboard");
  transmitter.update(heldState("buttons", "a")); clock.advance(3000);
  assert.equal(sent.length, 0);
});

test("unauthenticated session cannot keep a controller active", () => {
  const { clock, sent, transmitter } = setup();
  transmitter.deactivate(false);
  transmitter.update(heldState("buttons", "a")); clock.advance(3000);
  assert.equal(sent.length, 0);
});

test("every refresh carries the complete versioned state", () => {
  const { clock, sent, transmitter } = setup(2);
  const state = neutralState(); state.buttons.a = true; state.dpad.right = true; state.axes.lt = 0.5;
  transmitter.update(state); clock.advance(400);
  for (const { payload } of sent) {
    assert.equal(payload.type, "gamepad_state");
    assert.equal(payload.protocolVersion, 2);
    assert.equal(payload.player, 2);
    assert.ok(payload.buttons && payload.dpad && payload.axes);
  }
});

test("congestion drops old sends and later transmits only latest state", () => {
  const { clock, sent, transmitter, setWritable } = setup();
  setWritable(false);
  transmitter.update(heldState("dpad", "left"));
  const latest = heldState("dpad", "right"); transmitter.update(latest);
  clock.advance(400); assert.equal(sent.length, 0);
  setWritable(true); clock.advance(200);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].payload.sequence, 1);
  assert.equal(sent[0].payload.dpad.left, false);
  assert.equal(sent[0].payload.dpad.right, true);
});
