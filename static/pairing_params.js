(() => {
  "use strict";

  function parsePairingParameters(url) {
    const parsed = new URL(url, "http://celular-gamepad.local/");
    const pin = parsed.searchParams.get("pin") || "";
    const player = parsed.searchParams.get("player") || "auto";
    return {
      hasParameters: parsed.searchParams.has("pin") || parsed.searchParams.has("player"),
      pin: /^\d{6}$/.test(pin) ? pin : "",
      player: ["auto", "1", "2"].includes(player) ? player : "auto",
      playerValid: ["auto", "1", "2"].includes(player),
    };
  }

  function consumePairingParameters(browserWindow) {
    const result = parsePairingParameters(browserWindow.location.href);
    if (result.hasParameters && browserWindow.history?.replaceState) {
      browserWindow.history.replaceState(null, "", browserWindow.location.pathname + browserWindow.location.hash);
    }
    return result;
  }

  const api = { parsePairingParameters, consumePairingParameters };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else window.CelularPairing = api;
})();
