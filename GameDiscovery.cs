using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace Umbral {
    internal static class GameDiscovery {
        // Discovery is read-only. The installer still checks the exact build hashes.
        public static string Recognize(string input) {
            try {
                string root=Engine.ValidateFolder(input);
                foreach(string relative in new[]{"", "cod25", @"Content\cod25"}) {
                    string candidate=Path.Combine(root,relative).TrimEnd('\\','/');
                    if(!String.Equals(Path.GetFileName(candidate),"cod25",StringComparison.OrdinalIgnoreCase))continue;
                    bool present=true;
                    foreach(string name in new[]{"code_pre_gfx.ff","frontend_ui.ff","zm_sat_firefly.ff"}) {
                        var file=new FileInfo(Path.Combine(candidate,name));
                        if(!file.Exists||file.Length==0){present=false;break;}
                    }
                    if(present)return candidate;
                }
            } catch(IOException) {} catch(UnauthorizedAccessException) {} catch(ArgumentException) {} catch(System.Security.SecurityException) {} catch(NotSupportedException) {}
            return null;
        }
        internal static string GamingRoot(string volume,byte[] marker) {
            try {
                if(marker.Length<10||marker.Length>4096||(marker.Length%2)!=0||
                    marker[0]!=0x52||marker[1]!=0x47||marker[2]!=0x42||marker[3]!=0x58||
                    BitConverter.ToInt32(marker,4)!=1)return null;
                string relative=Encoding.Unicode.GetString(marker,8,marker.Length-8).TrimEnd('\0');
                if(String.IsNullOrWhiteSpace(relative)||Path.IsPathRooted(relative)||relative.IndexOf('\0')>=0)return null;
                string prefix=Engine.ValidateFolder(volume).TrimEnd('\\','/')+Path.DirectorySeparatorChar;
                string path=Path.GetFullPath(Path.Combine(prefix,relative));
                return path.StartsWith(prefix,StringComparison.OrdinalIgnoreCase)?path:null;
            } catch(ArgumentException) {} catch(NotSupportedException) {} catch(IOException) {}
            return null;
        }
        public static string[] SystemLibraries() {
            var roots=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach(var drive in DriveInfo.GetDrives()) {
                try {
                    if(drive.DriveType!=DriveType.Fixed||!drive.IsReady)continue;
                    string volume=drive.RootDirectory.FullName;
                    roots.Add(Path.Combine(volume,"XboxGames"));
                    string marker=Path.Combine(volume,".GamingRoot");
                    if(File.Exists(marker)&&new FileInfo(marker).Length<=4096) {
                        string custom=GamingRoot(volume,File.ReadAllBytes(marker));
                        if(custom!=null)roots.Add(custom);
                    }
                } catch(IOException) {} catch(UnauthorizedAccessException) {} catch(System.Security.SecurityException) {}
            }
            var result=new string[roots.Count];roots.CopyTo(result);return result;
        }
        public static string[] Find(IEnumerable<string> libraries) {
            var found=new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach(string library in libraries) {
                try {
                    string root=Engine.ValidateFolder(library);
                    string direct=Recognize(root);if(direct!=null)found.Add(direct);
                    if(!Directory.Exists(root))continue;
                    // Only inspect immediate library children; never scan an entire disk.
                    foreach(string child in Directory.GetDirectories(root)) {
                        if((File.GetAttributes(child)&FileAttributes.ReparsePoint)!=0)continue;
                        string game=Recognize(child);if(game!=null)found.Add(game);
                    }
                } catch(IOException) {} catch(UnauthorizedAccessException) {} catch(ArgumentException) {} catch(System.Security.SecurityException) {} catch(NotSupportedException) {}
            }
            var result=new string[found.Count];found.CopyTo(result);return result;
        }
    }
}
