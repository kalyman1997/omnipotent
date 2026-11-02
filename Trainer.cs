using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;

namespace Umbral {
    internal static class Trainer {
        [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr window);
        [DllImport("user32.dll")] static extern bool ShowWindowAsync(IntPtr window,int command);
        internal static string HashFile(string path){using(var stream=File.OpenRead(path))using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-","").ToLowerInvariant();}
        internal static void NoLinks(string path){for(string p=Path.GetFullPath(path);!String.IsNullOrEmpty(p);p=Path.GetDirectoryName(p))if((Directory.Exists(p)||File.Exists(p))&&(File.GetAttributes(p)&FileAttributes.ReparsePoint)!=0)throw new IOException("La carpeta del trainer contiene un enlace no admitido.");}
        internal static string EntryPath(string root,string name){
            string normalized=name.Replace('/', '\\');
            if(String.IsNullOrWhiteSpace(name)||Path.IsPathRooted(normalized)||normalized.Contains(":"))throw new InvalidDataException("Ruta no válida en el paquete del trainer.");
            foreach(string part in normalized.Split('\\'))if(part==".."||part=="."||part.TrimEnd(' ','.')!=part)throw new InvalidDataException("Ruta no válida en el paquete del trainer.");
            string prefix=Path.GetFullPath(root).TrimEnd('\\')+"\\";
            string path=Path.GetFullPath(Path.Combine(prefix,normalized));
            if(!path.StartsWith(prefix,StringComparison.OrdinalIgnoreCase))throw new InvalidDataException("Ruta fuera del paquete del trainer.");
            return path;
        }
        internal static void ExtractVerified(string archive,string root,Action<int,string> progress){
            NoLinks(root);Directory.CreateDirectory(root);
            using(var zip=ZipFile.OpenRead(archive)){
                if(zip.Entries.Count>4096)throw new InvalidDataException("Paquete del trainer demasiado grande.");
                long total=0;var paths=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                // Validate the complete index before writing anything from the archive.
                foreach(var entry in zip.Entries){string path=EntryPath(root,entry.FullName);if(!paths.Add(path))throw new InvalidDataException("Ruta duplicada en el trainer.");total+=entry.Length;if(total>128*1024*1024||entry.Length>64*1024*1024)throw new InvalidDataException("Paquete del trainer demasiado grande.");NoLinks(path);}
                int count=0;
                foreach(var entry in zip.Entries){
                    string path=EntryPath(root,entry.FullName);
                    if(entry.Name.Length==0){Directory.CreateDirectory(path);continue;}
                    byte[] content;using(var input=entry.Open())using(var memory=new MemoryStream()){input.CopyTo(memory);content=memory.ToArray();}
                    if(content.LongLength!=entry.Length)throw new InvalidDataException("Archivo incompleto en el trainer.");
                    if(!File.Exists(path)||new FileInfo(path).Length!=content.Length||HashFile(path)!=Bundle.Digest(content)){
                        Directory.CreateDirectory(Path.GetDirectoryName(path));string temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";
                        try{File.WriteAllBytes(temp,content);if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);}finally{if(File.Exists(temp))File.Delete(temp);}
                    }
                    count++;if(count%40==0)progress(75+count*24/Math.Max(1,zip.Entries.Count),"Preparando trainer…");
                }
            }
        }
        static Dictionary<string,object> Configuration(){
            var d=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(Path.Combine(Program.Root,"trainer.json")));
            Uri uri;string url=Convert.ToString(d["url"]),hash=Convert.ToString(d["sha256"]);
            if(!Uri.TryCreate(url,UriKind.Absolute,out uri)||uri.Scheme!="https"||uri.Host!="github.com"||!String.IsNullOrEmpty(uri.UserInfo)||!System.Text.RegularExpressions.Regex.IsMatch(hash,"^[a-f0-9]{64}$")||Convert.ToString(d["executable"])!="BO7_Kronos_Trainer.exe")throw new InvalidDataException("Configuración del trainer no válida.");
            return d;
        }
        internal static string Prepare(Action<int,string> progress){
            var d=Configuration();string hash=Convert.ToString(d["sha256"]);long expected=Convert.ToInt64(d["bytes"]);
            if(expected<=0||expected>64*1024*1024)throw new InvalidDataException("Tamaño del trainer no válido.");
            string basePath=Path.Combine(Bundle.Home,"mods"),root=Path.Combine(basePath,hash),archive=Path.Combine(basePath,hash+".zip");
            NoLinks(archive);NoLinks(root);Directory.CreateDirectory(basePath);
            using(var mutex=new Mutex(false,"Local\\Omnipotent.Trainer."+hash)){
                bool owns=false;try{
                    try{owns=mutex.WaitOne(TimeSpan.FromSeconds(60));}catch(AbandonedMutexException){owns=true;}
                    if(!owns)throw new IOException("Otra ventana está preparando el trainer. Inténtalo de nuevo.");
                    if(!File.Exists(archive)||new FileInfo(archive).Length!=expected||HashFile(archive)!=hash){
                        string temp=archive+"."+Guid.NewGuid().ToString("N")+".tmp";
                        try{
                            ServicePointManager.SecurityProtocol|=SecurityProtocolType.Tls12;
                            var request=(HttpWebRequest)WebRequest.Create(Convert.ToString(d["url"]));request.UserAgent="Omnipotent/1.1.0";request.Timeout=30000;request.ReadWriteTimeout=30000;
                            using(var response=(HttpWebResponse)request.GetResponse())using(var input=response.GetResponseStream())using(var output=File.Create(temp)){
                                if(response.ResponseUri.Scheme!="https")throw new IOException("La descarga del trainer requiere HTTPS.");
                                byte[] buffer=new byte[65536];long received=0;int read;
                                while((read=input.Read(buffer,0,buffer.Length))>0){received+=read;if(received>expected)throw new InvalidDataException("Tamaño de descarga incorrecto.");output.Write(buffer,0,read);progress((int)(received*74/expected),"Descargando trainer…");}
                            }
                            if(new FileInfo(temp).Length!=expected||HashFile(temp)!=hash)throw new InvalidDataException("La descarga del trainer no pasó la verificación. Vuelve a intentarlo.");
                            if(File.Exists(archive))File.Replace(temp,archive,null);else File.Move(temp,archive);
                        }finally{if(File.Exists(temp))File.Delete(temp);}
                    }
                    progress(75,"Verificando trainer…");ExtractVerified(archive,root,progress);
                    string exe=Path.Combine(root,Convert.ToString(d["executable"]));
                    if(!File.Exists(exe)||HashFile(exe)!=Convert.ToString(d["executableSha256"]))throw new InvalidDataException("El ejecutable del trainer no pasó la verificación.");
                    progress(100,"Trainer listo.");return exe;
                }finally{if(owns)mutex.ReleaseMutex();}
            }
        }
        static bool FocusExisting(){
            string root=Path.Combine(Bundle.Home,"mods")+Path.DirectorySeparatorChar;
            foreach(var process in Process.GetProcessesByName("BO7_Kronos_Trainer"))using(process){try{if(process.MainModule.FileName.StartsWith(root,StringComparison.OrdinalIgnoreCase)){ShowWindowAsync(process.MainWindowHandle,9);SetForegroundWindow(process.MainWindowHandle);return true;}}catch(System.ComponentModel.Win32Exception){}catch(InvalidOperationException){}}
            return false;
        }
        public static void Open(string game,Action<int,string> progress){
            if(FocusExisting()){progress(100,"Trainer abierto.");return;}
            string exe=Prepare(progress);
            if(!String.IsNullOrEmpty(game)){
                string config=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),@"BO7KronosTrainer\config.json");NoLinks(config);Directory.CreateDirectory(Path.GetDirectoryName(config));
                var serializer=new JavaScriptSerializer();var data=new Dictionary<string,object>();
                if(File.Exists(config)){try{data=serializer.Deserialize<Dictionary<string,object>>(File.ReadAllText(config))??data;}catch(ArgumentException){}}
                data["game_root"]=game;string temp=config+"."+Guid.NewGuid().ToString("N")+".tmp";
                try{File.WriteAllText(temp,serializer.Serialize(data),new UTF8Encoding(false));if(File.Exists(config))File.Replace(temp,config,null);else File.Move(temp,config);}finally{if(File.Exists(temp))File.Delete(temp);}
            }
            using(var process=Process.Start(new ProcessStartInfo(exe){WorkingDirectory=Path.GetDirectoryName(exe),UseShellExecute=false})){
                if(process==null)throw new IOException("No se pudo abrir el trainer.");
                if(process.WaitForExit(1500))throw new IOException("El trainer se cerró al iniciar (código "+process.ExitCode+").");
            }
            progress(100,"Trainer abierto.");
        }
    }
}
