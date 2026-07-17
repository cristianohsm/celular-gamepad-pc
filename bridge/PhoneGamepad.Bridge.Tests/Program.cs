using PhoneGamepad.Bridge;

var tests = new List<(string Name, Action Test)>();
void Test(string name, Action action) => tests.Add((name, action));
void Assert(bool condition, string message) { if (!condition) throw new Exception(message); }
string State(int player = 1, long sequence = 1, string axes = "{}", string buttons = "{}", string dpad = "{}") => $$"""{"type":"state","protocolVersion":2,"player":{{player}},"sequence":{{sequence}},"buttons":{{buttons}},"dpad":{{dpad}},"axes":{{axes}}}""";

Test("creates two logical slots", () => { var b = new FakeGamepadBackend(); b.CreateSlots(); Assert(b.States.Count == 2, "slot count"); });
Test("maps all buttons without leakage", () => { Assert(Protocol.TryParseState(State(buttons: "{\"a\":true,\"b\":true,\"x\":true,\"y\":true,\"lb\":true,\"rb\":true,\"view\":true,\"menu\":true,\"leftStick\":true,\"rightStick\":true}"), out var f, out _), "parse"); Assert(f!.Buttons.Values.All(v => v), "buttons"); });
Test("clamps analog values", () => { Protocol.TryParseState(State(axes: "{\"lx\":2,\"ly\":-2,\"lt\":2,\"rt\":-1}"), out var f, out _); Assert(f!.Axes["lx"] == 1 && f.Axes["ly"] == -1 && f.Axes["lt"] == 1 && f.Axes["rt"] == 0, "clamp"); });
Test("inverts vertical axes for HID", () => { Assert(HidMaestroStateMapper.StickY(1) == 0 && HidMaestroStateMapper.StickY(-1) == 1 && HidMaestroStateMapper.StickX(0) == .5f, "axis conversion"); });
Test("rejects NaN and infinity", () => { Assert(!Protocol.TryParseState(State(axes: "{\"lx\":NaN}"), out _, out _), "NaN"); Assert(!Protocol.TryParseState(State(axes: "{\"lx\":1e999}"), out _, out _), "infinity"); });
Test("drops old sequences", () => { var b = new FakeGamepadBackend(); b.CreateSlots(); using var e = new BridgeEngine(b); Protocol.TryParseState(State(sequence: 2), out var newer, out _); Protocol.TryParseState(State(sequence: 1), out var older, out _); Assert(e.Apply(newer!, DateTimeOffset.UtcNow), "new"); Assert(!e.Apply(older!, DateTimeOffset.UtcNow), "old"); });
Test("isolates players and triggers", () => { var b = new FakeGamepadBackend(); b.CreateSlots(); using var e = new BridgeEngine(b); Protocol.TryParseState(State(1,1,"{\"lt\":0.4}"), out var p1, out _); Protocol.TryParseState(State(2,1,"{\"rt\":0.8}"), out var p2, out _); e.Apply(p1!, DateTimeOffset.UtcNow); e.Apply(p2!, DateTimeOffset.UtcNow); Assert(b.States[1].Axes["lt"] == .4f && b.States[1].Axes["rt"] == 0 && b.States[2].Axes["rt"] == .8f, "leak"); });
Test("neutralizes one player only", () => { var b = new FakeGamepadBackend(); b.CreateSlots(); using var e = new BridgeEngine(b); Protocol.TryParseState(State(1,1,buttons:"{\"a\":true}"), out var p1, out _); Protocol.TryParseState(State(2,1,buttons:"{\"b\":true}"), out var p2, out _); e.Apply(p1!, DateTimeOffset.UtcNow); e.Apply(p2!, DateTimeOffset.UtcNow); e.Neutralize(1); Assert(!b.States[1].Buttons["a"] && b.States[2].Buttons["b"], "isolation"); });
Test("watchdog neutralizes stale state", () => { var b = new FakeGamepadBackend(); b.CreateSlots(); using var e = new BridgeEngine(b, TimeSpan.FromMilliseconds(500)); var now = DateTimeOffset.UtcNow; Protocol.TryParseState(State(buttons:"{\"a\":true}"), out var f, out _); e.Apply(f!, now); e.Tick(now.AddMilliseconds(501)); Assert(!b.States[1].Buttons["a"], "watchdog"); });
Test("accepts restarted sequence after neutralization", () => { var b = new FakeGamepadBackend(); b.CreateSlots(); using var e = new BridgeEngine(b); Protocol.TryParseState(State(sequence:99,buttons:"{\"a\":true}"), out var first, out _); Protocol.TryParseState(State(sequence:1,buttons:"{\"b\":true}"), out var second, out _); e.Apply(first!, DateTimeOffset.UtcNow); e.Neutralize(1); Assert(e.Apply(second!, DateTimeOffset.UtcNow) && b.States[1].Buttons["b"], "reconnect"); });
Test("rejects incompatible protocol", () => Assert(!Protocol.TryParseState(State().Replace("\"protocolVersion\":2", "\"protocolVersion\":99"), out _, out var error) && error == "incompatible_protocol", "protocol"));
Test("rejects invalid and oversized messages", () => { Assert(!Protocol.TryParseState("[]", out _, out _), "invalid"); Assert(!Protocol.TryParseState(new string('x', Protocol.MaxLineBytes + 1), out _, out var error) && error == "message_too_large", "large"); });
Test("backend errors are observable", () => { var b = new FakeGamepadBackend { FailApply = true }; b.CreateSlots(); using var e = new BridgeEngine(b); Protocol.TryParseState(State(), out var f, out _); try { e.Apply(f!, DateTimeOffset.UtcNow); throw new Exception("not thrown"); } catch (InvalidOperationException) { } });
Test("shutdown neutralizes and disposes", () => { var b = new FakeGamepadBackend(); b.CreateSlots(); Protocol.TryParseState(State(buttons:"{\"a\":true}"), out var f, out _); b.Apply(f!); b.Dispose(); Assert(b.Disposed && !b.States[1].Buttons["a"], "dispose"); });

var failures = 0;
foreach (var (name, action) in tests) { try { action(); Console.WriteLine($"PASS {name}"); } catch (Exception ex) { failures++; Console.Error.WriteLine($"FAIL {name}: {ex.Message}"); } }
Console.WriteLine($"{tests.Count - failures}/{tests.Count} bridge tests passed");
return failures == 0 ? 0 : 1;
