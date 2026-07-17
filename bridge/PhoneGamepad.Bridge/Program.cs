using System.Text.Json;
using PhoneGamepad.Bridge;

static void Emit(object payload) => Console.WriteLine(JsonSerializer.Serialize(payload));

var argsSet = args.ToHashSet(StringComparer.OrdinalIgnoreCase);
if (argsSet.Contains("--check"))
{
    using var backend = new HidMaestroGamepadBackend();
    Emit(new { type = "check", installed = backend.IsInstalled, protocolVersion = Protocol.Version });
    return;
}
if (argsSet.Contains("--install"))
{
    using var backend = new HidMaestroGamepadBackend();
    backend.Install();
    Emit(new { type = "install", ok = true });
    return;
}
if (argsSet.Contains("--cleanup"))
{
    HidMaestroGamepadBackend.CleanupAll();
    Emit(new { type = "cleanup", ok = true });
    return;
}

IVirtualGamepadBackend selected = argsSet.Contains("--backend=fake") || argsSet.Contains("--fake") ? new FakeGamepadBackend() : new HidMaestroGamepadBackend();
using var engine = new BridgeEngine(selected);
using var cancellation = new CancellationTokenSource();
var watchdogTask = Task.Run(async () => { while (!cancellation.IsCancellationRequested) { await Task.Delay(100, cancellation.Token).ConfigureAwait(false); engine.Tick(DateTimeOffset.UtcNow); } }, cancellation.Token);
Emit(new { type = "bridge_ready", protocolVersion = Protocol.Version, capabilities = new { players = 2, profile = "xbox-360-wired", watchdogMs = 750, transport = "stdio" } });

try
{
    string? line;
    while ((line = Console.ReadLine()) is not null)
    {
        if (System.Text.Encoding.UTF8.GetByteCount(line) > Protocol.MaxLineBytes) { Emit(new { type = "error", code = "message_too_large" }); continue; }
        try
        {
            using var document = JsonDocument.Parse(line, new JsonDocumentOptions { MaxDepth = 8 });
            var root = document.RootElement;
            var type = root.ValueKind == JsonValueKind.Object && root.TryGetProperty("type", out var value) ? value.GetString() : null;
            if (type == "hello") { Emit(new { type = "hello", ok = true, protocolVersion = Protocol.Version }); continue; }
            if (type == "create") { engine.CreateSlots(); Emit(new { type = "controllers_ready", players = new[] { 1, 2 } }); continue; }
            if (type == "neutralize" && root.TryGetProperty("player", out var p) && p.TryGetInt32(out var player) && player is 1 or 2) { engine.Neutralize(player); continue; }
            if (type == "shutdown") break;
            if (!Protocol.TryParseState(line, out var frame, out var error) || frame is null) { Emit(new { type = "error", code = error }); continue; }
            engine.Apply(frame, DateTimeOffset.UtcNow);
        }
        catch (Exception ex) when (ex is JsonException or InvalidOperationException or UnauthorizedAccessException)
        {
            Emit(new { type = "error", code = "controlled_failure", message = ex.Message });
        }
    }
}
finally
{
    cancellation.Cancel();
    try { await watchdogTask.ConfigureAwait(false); } catch (OperationCanceledException) { }
}
