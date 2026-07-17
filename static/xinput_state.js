(function (root, factory) {
  "use strict";
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.XInputStateTransmitter = api.XInputStateTransmitter;
})(typeof globalThis !== "undefined" ? globalThis : this, () => {
  "use strict";

  const BUTTON_NAMES = ["a", "b", "x", "y", "lb", "rb", "view", "menu", "leftStick", "rightStick"];
  const DPAD_NAMES = ["up", "down", "left", "right"];
  const AXIS_NAMES = ["lx", "ly", "rx", "ry", "lt", "rt"];

  function neutralState() {
    return {
      buttons: Object.fromEntries(BUTTON_NAMES.map((name) => [name, false])),
      dpad: Object.fromEntries(DPAD_NAMES.map((name) => [name, false])),
      axes: Object.fromEntries(AXIS_NAMES.map((name) => [name, 0])),
    };
  }

  function copyState(state) {
    return {
      buttons: { ...state.buttons },
      dpad: { ...state.dpad },
      axes: { ...state.axes },
    };
  }

  function isNeutral(state) {
    return !Object.values(state.buttons).some(Boolean)
      && !Object.values(state.dpad).some(Boolean)
      && !Object.values(state.axes).some((value) => Math.abs(Number(value) || 0) > 0.0001);
  }

  class XInputStateTransmitter {
    constructor({ send, now, timestamp, setTimeoutFn, clearTimeoutFn, refreshMs = 200, maxHz = 60 }) {
      this.send = send;
      this.now = now;
      this.timestamp = timestamp;
      this.setTimeoutFn = setTimeoutFn;
      this.clearTimeoutFn = clearTimeoutFn;
      this.refreshMs = refreshMs;
      this.minSendMs = 1000 / maxHz;
      this.state = neutralState();
      this.authenticated = false;
      this.outputMode = "keyboard";
      this.player = null;
      this.sequence = 0;
      this.lastSendAt = Number.NEGATIVE_INFINITY;
      this.pendingTimer = null;
      this.refreshTimer = null;
    }

    setSession({ authenticated, outputMode, player }) {
      const nextPlayer = Number(player) || null;
      const changed = !authenticated || !this.authenticated || nextPlayer !== this.player || outputMode !== this.outputMode;
      this.authenticated = Boolean(authenticated);
      this.outputMode = outputMode === "xinput" ? "xinput" : "keyboard";
      this.player = nextPlayer;
      if (changed) {
        this.cancelTimers();
        this.state = neutralState();
        this.sequence = 0;
        this.lastSendAt = Number.NEGATIVE_INFINITY;
      }
    }

    update(state, immediate = false) {
      this.state = copyState(state);
      if (!this.canSend()) {
        this.cancelTimers();
        return false;
      }
      if (immediate && this.pendingTimer !== null) {
        this.clearTimeoutFn(this.pendingTimer);
        this.pendingTimer = null;
      }
      const sent = immediate ? this.transmit() : this.requestSend();
      if (isNeutral(this.state)) this.cancelRefresh();
      else this.scheduleRefresh();
      return sent;
    }

    deactivate(sendNeutral = false) {
      if (sendNeutral && this.canSend()) {
        this.state = neutralState();
        this.transmit();
      }
      this.cancelTimers();
      this.state = neutralState();
      this.authenticated = false;
      this.player = null;
      this.outputMode = "keyboard";
    }

    canSend() {
      return this.authenticated && this.outputMode === "xinput" && this.player !== null;
    }

    requestSend() {
      const wait = Math.max(0, this.minSendMs - (this.now() - this.lastSendAt));
      if (wait === 0) return this.transmit();
      if (this.pendingTimer === null) {
        this.pendingTimer = this.setTimeoutFn(() => {
          this.pendingTimer = null;
          this.transmit();
        }, wait);
      }
      return false;
    }

    transmit() {
      if (!this.canSend()) return false;
      const nextSequence = this.sequence + 1;
      const accepted = this.send({
        type: "gamepad_state",
        protocolVersion: 2,
        player: this.player,
        sequence: nextSequence,
        timestamp: this.timestamp(),
        ...copyState(this.state),
      });
      if (accepted === false) return false;
      this.sequence = nextSequence;
      this.lastSendAt = this.now();
      return true;
    }

    scheduleRefresh() {
      if (this.refreshTimer !== null || !this.canSend() || isNeutral(this.state)) return;
      this.refreshTimer = this.setTimeoutFn(() => {
        this.refreshTimer = null;
        if (!this.canSend() || isNeutral(this.state)) return;
        this.transmit();
        this.scheduleRefresh();
      }, this.refreshMs);
    }

    cancelRefresh() {
      if (this.refreshTimer !== null) this.clearTimeoutFn(this.refreshTimer);
      this.refreshTimer = null;
    }

    cancelTimers() {
      if (this.pendingTimer !== null) this.clearTimeoutFn(this.pendingTimer);
      this.pendingTimer = null;
      this.cancelRefresh();
    }
  }

  return { XInputStateTransmitter, neutralState, isNeutral };
});
