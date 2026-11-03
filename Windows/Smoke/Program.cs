using System;
using System.IO;
using System.Linq;
using Miaotou;
static void Check(bool value,string name) { if(!value)throw new Exception(name);Console.WriteLine("PASS "+name); }
var state=new ThingState();state.Save("Launch my first website");var old=state.Active;
try{state.Save(new string('字',17));throw new Exception("accepted invalid");}catch(ArgumentException){}
Check(state.Active==old&&state.History.Count==0,"invalid input preserves active thing");
state.Save("Write my first essay");Check(state.History.Count==1&&!state.History[0].Completed,"replacement archives unfinished");
Check(state.Complete()!=null&&state.Complete()==null&&state.History.Count==2,"completion is idempotent");
Check(Budget.Count("👨‍👩‍👧‍👦")==1&&Budget.Limit("做个 app")==16&&Budget.Limit("Build an app")==36,"unicode graphemes and mixed limit");
state.Save("Launch my first website");string a=Tips.Line(state,Clock.From(state.Active!.CreatedAt));string b=Tips.Line(state,Clock.From(state.Active.CreatedAt).AddDays(1));Check(a!=b,"daily rotation");
var folder=Path.Combine(Path.GetTempPath(),"Miaotou-Windows-Test-"+Guid.NewGuid());
try { var disk=new Disk(folder);var doc=new Document{State=state};disk.Write(doc);Check(disk.Load().State.Active==state.Active,"disk roundtrip");File.WriteAllText(disk.FilePath,"broken");try{disk.Load();throw new Exception("accepted corrupt file");}catch(System.Text.Json.JsonException){}Check(File.ReadAllText(disk.FilePath)=="broken","corrupt data not overwritten"); } finally{Directory.Delete(folder,true);}
if(args.Length>0){var imported=System.Text.Json.JsonSerializer.Deserialize<ThingState>(File.ReadAllText(args[0]),Disk.Json)!;Check(imported.Schema==1&&imported.History.Any(h=>h.Completed)&&imported.History.Any(h=>!h.Completed),"real Swift record imports with history states");}
