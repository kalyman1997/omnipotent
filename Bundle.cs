using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

namespace Umbral {
    internal static class Bundle {
        const string Prefix="Omnipotent.Bundle.";
        public static readonly bool IsEmbedded=Assembly.GetExecutingAssembly().GetManifestResourceNames().Any(n=>n.StartsWith(Prefix,StringComparison.Ordinal));
        public static string Home {get{return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Omnipotent");}}
        public static string Digest(byte[] bytes){using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-","").ToLowerInvariant();}
        static void NoLinks(string path){for(string p=Path.GetFullPath(path);!String.IsNullOrEmpty(p);p=Path.GetDirectoryName(p)){if((File.Exists(p)||Directory.Exists(p))&&(File.GetAttributes(p)&FileAttributes.ReparsePoint)!=0)throw new IOException("La carpeta de Omnipotent contiene un enlace no admitido.");}}
        public static string Prepare(){
            if(!IsEmbedded)return AppDomain.CurrentDomain.BaseDirectory;
            var assembly=Assembly.GetExecutingAssembly();var resources=assembly.GetManifestResourceNames().Where(n=>n.StartsWith(Prefix,StringComparison.Ordinal)).OrderBy(n=>n,StringComparer.Ordinal).ToArray();
            var payloads=new System.Collections.Generic.Dictionary<string,byte[]>();var manifest=new StringBuilder();
            foreach(var name in resources){string relative=name.Substring(Prefix.Length);if(relative.StartsWith("/")||relative.Contains("..")||relative.Contains(":"))throw new IOException("Recurso no valido.");using(var stream=assembly.GetManifestResourceStream(name))using(var memory=new MemoryStream()){stream.CopyTo(memory);byte[] bytes=memory.ToArray();payloads.Add(relative,bytes);manifest.Append(relative).Append(':').Append(Digest(bytes)).Append('\n');}}
            string id=Digest(Encoding.UTF8.GetBytes(manifest.ToString()));string root=Path.Combine(Home,"runtime",id);NoLinks(root);
            using(var mutex=new Mutex(false,"Local\\Omnipotent.Bundle."+id)){
                bool owns=false;try{try{owns=mutex.WaitOne(TimeSpan.FromSeconds(30));}catch(AbandonedMutexException){owns=true;}if(!owns)throw new IOException("Otra instancia esta preparando Omnipotent.");
                    Directory.CreateDirectory(root);
                    foreach(var entry in payloads){string path=Path.Combine(root,entry.Key.Replace('/',Path.DirectorySeparatorChar));NoLinks(path);Directory.CreateDirectory(Path.GetDirectoryName(path));if(File.Exists(path)&&Digest(File.ReadAllBytes(path))==Digest(entry.Value))continue;
                        string temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";try{File.WriteAllBytes(temp,entry.Value);if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);}finally{if(File.Exists(temp))File.Delete(temp);}
                    }
                }finally{if(owns)mutex.ReleaseMutex();}
            }return root;
        }
        public static string Store(string game){
            if(!IsEmbedded)return Path.Combine(Program.Root,"data");
            string key=Digest(Encoding.UTF8.GetBytes(Path.GetFullPath(game).TrimEnd('\\','/').ToUpperInvariant()));
            string path=Path.Combine(Home,"installations",key);NoLinks(path);return path;
        }
    }
}
