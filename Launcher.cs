using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using System.Xml;

[assembly: System.Reflection.AssemblyTitle("Omnipotent 1.0")]
[assembly: System.Reflection.AssemblyProduct("Omnipotent")]
[assembly: System.Reflection.AssemblyDescription("Gestor híbrido: offline con Kronos y online desde Xbox")]
[assembly: System.Reflection.AssemblyVersion("1.3.0.0")]
[assembly: System.Reflection.AssemblyFileVersion("1.3.0.0")]
[assembly: System.Reflection.AssemblyInformationalVersion("1.3.0")]

namespace Umbral {
    internal sealed class EngineResult {
        public bool Ok; public string State, Message; public string[] Details, Can;
        public static EngineResult Failure(string message) { return new EngineResult { Ok = false, State = "Unknown", Message = message, Details = new string[0], Can = new string[] { "Status" } }; }
        public static EngineResult Parse(string json) {
            Dictionary<string, object> d = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(json.Trim().TrimStart('\uFEFF'));
            if (d == null || !d.ContainsKey("ok") || !d.ContainsKey("state") || !d.ContainsKey("message") || !d.ContainsKey("can")) throw new InvalidDataException("El motor devolvió una respuesta incompleta.");
            return new EngineResult { Ok = Convert.ToBoolean(d["ok"]), State = Convert.ToString(d["state"]), Message = Convert.ToString(d["message"]), Details = Strings(d.ContainsKey("details") ? d["details"] : null), Can = Strings(d["can"]) };
        }
        static string[] Strings(object value) {
            if (value == null) return new string[0];
            List<string> values = new List<string>();
            System.Collections.IEnumerable list = value as System.Collections.IEnumerable;
            if (list == null || value is string) throw new InvalidDataException("El motor devolvió una lista no válida.");
            foreach (object item in list) values.Add(Convert.ToString(item)); return values.ToArray();
        }
        public bool Allows(string action) { return Ok && Array.IndexOf(Can, action) >= 0; }
        public string Report() { return "OMNIPOTENT 1.0 / HÍBRIDO\r\n" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "\r\nEstado: " + State + "\r\n" + Message + "\r\n\r\n" + String.Join("\r\n", Details ?? new string[0]); }
    }
    internal static class Engine {
        public static string ValidateFolder(string input) {
            if (String.IsNullOrWhiteSpace(input)) throw new ArgumentException("Selecciona la carpeta del juego.");
            string p = input.Trim();
            if (p.StartsWith(@"\\", StringComparison.Ordinal)) throw new ArgumentException("Selecciona una carpeta local, no una ruta de red.");
            if (p.Length < 3 || !Char.IsLetter(p[0]) || p[1] != ':' || (p[2] != '\\' && p[2] != '/')) throw new ArgumentException("Usa una ruta absoluta para la carpeta del juego.");
            return Path.GetFullPath(p);
        }
        public static string Quote(string text) {
            StringBuilder b = new StringBuilder("\""); int slashes = 0;
            foreach (char c in text) {
                if (c == '\\') { slashes++; continue; }
                if (c == '"') { b.Append('\\', slashes * 2 + 1); b.Append(c); slashes = 0; continue; }
                b.Append('\\', slashes); slashes = 0; b.Append(c);
            }
            b.Append('\\', slashes * 2); b.Append('"'); return b.ToString();
        }
        public static EngineResult Run(string action, string game, bool confirm) { return Run(action,game,confirm,null); }
        public static EngineResult Run(string action, string game, bool confirm, Action<int,string> progress) {
            game = ValidateFolder(game);
            string script = Path.Combine(Program.Root, "Hybrid.ps1");
            if (!File.Exists(script)) return EngineResult.Failure("No se encuentra Hybrid.ps1 junto al launcher.");
            string shell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
            string arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " + Quote(script) + " -Action " + Quote(action) + " -GamePath " + Quote(game) + " -StorePath " + Quote(Bundle.Store(game)) + (confirm ? " -ConfirmXboxRepair" : "") + (progress!=null ? " -ReportProgress" : "");
            ProcessStartInfo start = new ProcessStartInfo(shell, arguments) { UseShellExecute = false, CreateNoWindow = true, WindowStyle = ProcessWindowStyle.Hidden, RedirectStandardOutput = true, RedirectStandardError = true, StandardOutputEncoding = Encoding.UTF8, StandardErrorEncoding = Encoding.UTF8, WorkingDirectory = Program.Root };
            StringBuilder output = new StringBuilder(), errors = new StringBuilder();
            using (Process process = new Process { StartInfo = start }) {
                process.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e) {
                    if(e.Data==null)return;
                    if(e.Data.StartsWith("@progress ",StringComparison.Ordinal)){
                        try{var item=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(e.Data.Substring(10));int value=Convert.ToInt32(item["value"]);if(progress!=null)progress(Math.Max(-1,Math.Min(100,value)),Convert.ToString(item["message"]));}catch{}
                    }else{lock(output)output.AppendLine(e.Data);}
                };
                process.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) { lock (errors) errors.AppendLine(e.Data); } };
                process.Start(); process.BeginOutputReadLine(); process.BeginErrorReadLine(); process.WaitForExit();
                string body = output.ToString();
                if (String.IsNullOrWhiteSpace(body)) return EngineResult.Failure("El motor no devolvió un informe. " + errors.ToString().Trim());
                EngineResult result;
                try { result = EngineResult.Parse(body); }
                catch (Exception ex) { return EngineResult.Failure("No se pudo interpretar la respuesta del motor: " + ex.Message + "\r\n" + body + "\r\n" + errors); }
                if (process.ExitCode != 0 && result.Ok) return EngineResult.Failure("El motor terminó con código " + process.ExitCode + ". " + result.Message + "\r\n" + errors);
                return result;
            }
        }
    }
    internal static class Program {
        public static string Root = AppDomain.CurrentDomain.BaseDirectory;
        public static string DefaultGame {get{return "";}}
        public static string SettingsPath { get { return Path.Combine(Bundle.IsEmbedded?Bundle.Home:Root, "settings.xml"); } }
        [STAThread] static int Main(string[] args) {
            try {
                Root=Bundle.Prepare();
                if(args.Length>1&&args[0]=="--detect-game") {File.WriteAllText(args[1],new JavaScriptSerializer().Serialize(GameDiscovery.Find(GameDiscovery.SystemLibraries())),Encoding.UTF8);return 0;}
                if(args.Length>0&&args[0]=="--bundle-info") {File.WriteAllText(args[1],new JavaScriptSerializer().Serialize(new{embedded=Bundle.IsEmbedded,runtime=Root,settings=SettingsPath,defaultGame=DefaultGame}),Encoding.UTF8);return 0;}
                if (args.Length > 0 && args[0] == "--self-test") return SelfTest(args.Length > 1 ? args[1] : Path.Combine(Root, "self-test.txt"));
                if (args.Length > 0 && args[0] == "--diagnose") {
                    EngineResult result = Engine.Run("Status", args.Length > 1 ? args[1] : DefaultGame, false);
                    File.WriteAllText(args.Length > 2 ? args[2] : Path.Combine(Root, "diagnostico.txt"), result.Report(), Encoding.UTF8); return result.Ok ? 0 : 2;
                }
                bool preview = args.Length > 0 && args[0] == "--render-preview";
                Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
                using (Launcher form = new Launcher(!preview)) {
                    if (preview) {
                        form.CreateControl(); form.Show(); Application.DoEvents();
                        form.PreviewState(args.Length>2?args[2]:"idle"); Application.DoEvents();
                        using (Bitmap bitmap = new Bitmap(form.Width, form.Height)) { form.DrawToBitmap(bitmap, new Rectangle(Point.Empty, form.Size)); bitmap.Save(args.Length > 1 ? args[1] : Path.Combine(Root, "preview.png")); }
                        return 0;
                    }
                    Application.Run(form);
                }
                return 0;
            } catch (Exception ex) { if (args.Length == 0) MessageBox.Show(ex.Message, "Omnipotent 1.0 / Error", MessageBoxButtons.OK, MessageBoxIcon.Error); return 1; }
        }
        static int SelfTest(string path) {
            StringBuilder report = new StringBuilder("OMNIPOTENT 1.0 / AUTOPRUEBA\r\n"); int failures = 0;
            Action<bool, string> check = delegate(bool pass, string name) { report.AppendLine((pass ? "PASS " : "FAIL ") + name); if (!pass) failures++; };
            foreach (string input in new string[] { "", "relative", "C:relative", @"\\server\share" }) { bool rejected = false; try { Engine.ValidateFolder(input); } catch (ArgumentException) { rejected = true; } check(rejected, "Rechazo de ruta: " + input); }
            check(Engine.ValidateFolder(@"D:\Juego con espacios y ñ\cod25") == @"D:\Juego con espacios y ñ\cod25", "Ruta Unicode preservada");
            check(Engine.Quote("D:\\a b\\") == "\"D:\\a b\\\\\"", "Escape de barra final en argumento");
            check(Engine.Quote("a\"b") == "\"a\\\"b\"", "Escape de comillas en argumento");
            EngineResult state = EngineResult.Parse("{\"ok\":true,\"state\":\"NeedsXboxRepair\",\"message\":\"Reparación requerida\",\"details\":[\"No certifica online\"],\"can\":[\"Status\",\"CaptureOnline\"]}");
            check(state.Allows("CaptureOnline") && !state.Allows("LaunchOffline"), "Acciones filtradas por estado");
            check(!EngineResult.Failure("x").Allows("Status"), "Error no habilita acciones de estado");
            bool malformed = false; try { EngineResult.Parse("{\"ok\":true}"); } catch { malformed = true; } check(malformed, "Respuesta incompleta rechazada");
            check(state.Report().Contains("Reparación requerida"), "Informe conserva texto y estado");
            report.AppendLine("Fallos: " + failures); File.WriteAllText(path, report.ToString(), Encoding.UTF8); return failures == 0 ? 0 : 1;
        }
    }
}
