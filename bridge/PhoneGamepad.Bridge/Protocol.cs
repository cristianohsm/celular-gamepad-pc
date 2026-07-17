using System.Text.Json;

namespace PhoneGamepad.Bridge;

public static class Protocol
{
    public const int Version = 2;
    public const int MaxLineBytes = 16 * 1024;
    public static readonly string[] ButtonNames = ["a", "b", "x", "y", "lb", "rb", "view", "menu", "leftStick", "rightStick"];
    public static readonly string[] DpadNames = ["up", "down", "left", "right"];
    public static readonly string[] AxisNames = ["lx", "ly", "rx", "ry", "lt", "rt"];
    private static readonly HashSet<string> RootFields = ["type", "protocolVersion", "player", "sequence", "timestamp", "buttons", "dpad", "axes"];

    public static bool TryParseState(string line, out GamepadFrame? frame, out string error)
    {
        frame = null;
        error = "invalid_message";
        if (System.Text.Encoding.UTF8.GetByteCount(line) > MaxLineBytes) { error = "message_too_large"; return false; }
        try
        {
            using var document = JsonDocument.Parse(line, new JsonDocumentOptions { MaxDepth = 8 });
            var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object) return false;
            foreach (var property in root.EnumerateObject())
                if (!RootFields.Contains(property.Name)) { error = "unknown_field"; return false; }
            if (!root.TryGetProperty("type", out var type) || type.GetString() != "state") { error = "invalid_type"; return false; }
            if (!root.TryGetProperty("protocolVersion", out var version) || version.GetInt32() != Version) { error = "incompatible_protocol"; return false; }
            if (!root.TryGetProperty("player", out var playerElement) || !playerElement.TryGetInt32(out var player) || player is < 1 or > 2) { error = "invalid_player"; return false; }
            if (!root.TryGetProperty("sequence", out var sequenceElement) || !sequenceElement.TryGetInt64(out var sequence) || sequence < 0) { error = "invalid_sequence"; return false; }

            var buttons = ParseBools(root, "buttons", ButtonNames, ref error);
            if (buttons is null) return false;
            var dpad = ParseBools(root, "dpad", DpadNames, ref error);
            if (dpad is null) return false;
            var axes = ParseAxes(root, ref error);
            if (axes is null) return false;
            frame = new GamepadFrame(player, sequence, buttons, dpad, axes);
            error = "";
            return true;
        }
        catch (JsonException) { error = "invalid_json"; return false; }
        catch (InvalidOperationException) { error = "invalid_value"; return false; }
        catch (FormatException) { error = "invalid_value"; return false; }
    }

    private static Dictionary<string, bool>? ParseBools(JsonElement root, string name, string[] allowed, ref string error)
    {
        var result = allowed.ToDictionary(item => item, _ => false);
        if (!root.TryGetProperty(name, out var group)) return result;
        if (group.ValueKind != JsonValueKind.Object) { error = "invalid_" + name; return null; }
        foreach (var property in group.EnumerateObject())
        {
            if (!result.ContainsKey(property.Name) || property.Value.ValueKind is not (JsonValueKind.True or JsonValueKind.False)) { error = "invalid_" + name; return null; }
            result[property.Name] = property.Value.GetBoolean();
        }
        return result;
    }

    private static Dictionary<string, float>? ParseAxes(JsonElement root, ref string error)
    {
        var result = AxisNames.ToDictionary(item => item, _ => 0f);
        if (!root.TryGetProperty("axes", out var group)) return result;
        if (group.ValueKind != JsonValueKind.Object) { error = "invalid_axes"; return null; }
        foreach (var property in group.EnumerateObject())
        {
            if (!result.ContainsKey(property.Name) || property.Value.ValueKind != JsonValueKind.Number || !property.Value.TryGetSingle(out var value) || !float.IsFinite(value)) { error = "invalid_axes"; return null; }
            result[property.Name] = property.Name is "lt" or "rt" ? Math.Clamp(value, 0f, 1f) : Math.Clamp(value, -1f, 1f);
        }
        return result;
    }
}
