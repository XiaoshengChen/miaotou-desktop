using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Text.Json;

namespace Miaotou;
public sealed record Thing(Guid Id, string Text, double CreatedAt);
public sealed record PastThing(Guid Id, string Text, double Date, bool Completed);
public sealed class ThingState {
    public int Schema { get; set; } = 1;
    public Thing? Active { get; set; }
    public List<PastThing> History { get; set; } = new();
    public string Language { get; set; } = "en";
    public bool CompanionEnabled { get; set; } = true;
    public bool GuidanceDismissed { get; set; } = true;
    public Dictionary<string,string> GeneratedTips { get; set; } = new();
    public void Save(string input) {
        string text = Budget.Normalize(input);
        if (!Budget.Valid(text)) throw new ArgumentException("invalid text");
        if (Active is { } old) History.Insert(0,new(old.Id,old.Text,Clock.Now,false));
        Active = new(Guid.NewGuid(),text,Clock.Now); GeneratedTips.Clear();
    }
    public Thing? Complete() {
        if (Active is not { } old) return null;
        History.Insert(0,new(old.Id,old.Text,Clock.Now,true)); Active=null;GeneratedTips.Clear();return old;
    }
}
public sealed class Preferences {
    public bool Pinned { get; set; } = true;
    public bool Collapsed { get; set; }
    public double? X { get; set; }
    public double? Y { get; set; }
}
public sealed class Document {
    public int Version { get; set; } = 1;
    public ThingState State { get; set; } = new();
    public Preferences Preferences { get; set; } = new();
}
public static class Clock {
    public static readonly DateTime Epoch = new(2001,1,1,0,0,0,DateTimeKind.Utc);
    public static double Now => (DateTime.UtcNow-Epoch).TotalSeconds;
    public static DateTime From(double value) => Epoch.AddSeconds(value).ToLocalTime();
}
public static class Budget {
    public static string Normalize(string text) => string.Join(" ",text.Split((char[]?)null,StringSplitOptions.RemoveEmptyEntries));
    public static int Count(string text) => new StringInfo(text).LengthInTextElements;
    public static int Limit(string text) => text.EnumerateRunes().Any(r=>(r.Value>=0x2E80 && r.Value<=0x9FFF)||(r.Value>=0xAC00 && r.Value<=0xD7AF)||(r.Value>=0xF900 && r.Value<=0xFAFF)||(r.Value>=0xFF00 && r.Value<=0xFFEF)||r.Value>=0x1F000) ? 16:36;
    public static bool Valid(string text) => text.Length>0 && Count(text)<=Limit(text);
}
public sealed class Disk {
    public static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy=JsonNamingPolicy.CamelCase, PropertyNameCaseInsensitive=true };
    public string FilePath { get; }
    public Disk(string folder) { FilePath=Path.Combine(folder,"desktop-v1.json"); }
    public Document Load() {
        if (!File.Exists(FilePath)) return new();
        var doc=JsonSerializer.Deserialize<Document>(File.ReadAllText(FilePath),Json) ?? throw new InvalidDataException();
        if(doc.Version!=1 || doc.State.Schema!=1 || doc.State.History==null || doc.State.GeneratedTips==null || doc.Preferences==null) throw new InvalidDataException();
        return doc;
    }
    public void Write(Document doc) {
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
        string temp=FilePath+"."+Guid.NewGuid()+".tmp";
        try { File.WriteAllText(temp,JsonSerializer.Serialize(doc,Json),Encoding.UTF8);File.Move(temp,FilePath,true); }
        finally { if(File.Exists(temp)) File.Delete(temp); }
    }
    public static Document Copy(Document value) => JsonSerializer.Deserialize<Document>(JsonSerializer.Serialize(value,Json),Json)!;
}
public static class Tips {
    static readonly Dictionary<string,List<List<string>>> pools=Load();
    static Dictionary<string,List<List<string>>> Load() {
        var a=Assembly.GetExecutingAssembly();string resource=a.GetManifestResourceNames().Single(n=>n.EndsWith("tips.json"));
        using var stream=a.GetManifestResourceStream(resource)!;
        return JsonSerializer.Deserialize<Dictionary<string,List<List<string>>>>(stream)!;
    }
    public static string Line(ThingState state, DateTime? at=null) {
        var date=at??DateTime.Now;bool zh=state.Language=="zh";
        if(state.Active is not {} thing) return zh?"给想做的事留一个位置。":"Give your idea a place.";
        string key=$"{date.Year}-{date.Month}-{date.Day}";
        if(state.GeneratedTips.TryGetValue(key,out var cached) && !cached.Contains('\n') && Budget.Count(cached)<=38) return cached;
        string text=thing.Text.ToLowerInvariant();string branch="";
        if(new[]{"网站","website","landing","网页"}.Any(text.Contains))branch="website";
        else if(new[]{"app","应用","产品","软件"}.Any(text.Contains))branch="app";
        else if(new[]{"写","文章","write","book","newsletter"}.Any(text.Contains))branch="writing";
        var pool=new List<List<string>>();if(branch!="")pool.AddRange(pools[branch]);pool.AddRange(pools["general"]);
        int day=Math.Max(0,(date.Date-Clock.From(thing.CreatedAt).Date).Days);return pool[day%pool.Count][zh?1:0];
    }
}
