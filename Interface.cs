using System;
using System.ComponentModel;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;
using System.Xml;

namespace Umbral {
    internal static class Design {
        public static readonly Color Background = Color.FromArgb(12,13,18), Surface = Color.FromArgb(22,23,32), Ink = Color.FromArgb(242,240,250), Muted = Color.FromArgb(143,144,164), Violet = Color.FromArgb(179,155,255);
        public static GraphicsPath Round(RectangleF r, float radius) {
            float d=radius*2; GraphicsPath p=new GraphicsPath();
            p.AddArc(r.X,r.Y,d,d,180,90); p.AddArc(r.Right-d,r.Y,d,d,270,90);
            p.AddArc(r.Right-d,r.Bottom-d,d,d,0,90); p.AddArc(r.X,r.Bottom-d,d,d,90,90); p.CloseFigure(); return p;
        }
    }
    internal sealed class ActionButton : Button {
        public bool Primary; bool hover;
        public ActionButton() { SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer,true); FlatStyle=FlatStyle.Flat; FlatAppearance.BorderSize=0; Cursor=Cursors.Hand; Font=new Font("Segoe UI",12,FontStyle.Bold); BackColor=Design.Background; }
        protected override void OnMouseEnter(EventArgs e){hover=true;Invalidate();base.OnMouseEnter(e);}
        protected override void OnMouseLeave(EventArgs e){hover=false;Invalidate();base.OnMouseLeave(e);}
        protected override void OnPaint(PaintEventArgs e){
            e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
            Color fill=Primary?(Enabled?(hover?Color.FromArgb(202,183,255):Design.Violet):Color.FromArgb(51,45,68)):(hover&&Enabled?Color.FromArgb(36,35,49):Design.Surface);
            using(var path=Design.Round(new RectangleF(1,1,Width-3,Height-3),12))using(var brush=new SolidBrush(fill))using(var pen=new Pen(Primary?fill:Color.FromArgb(55,53,72))){e.Graphics.FillPath(brush,path);e.Graphics.DrawPath(pen,path);}
            Color ink=Enabled?(Primary?Color.FromArgb(27,19,46):Design.Ink):Color.FromArgb(127,120,145);
            TextRenderer.DrawText(e.Graphics,Text,Font,ClientRectangle,ink,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);
            if(Focused&&ShowFocusCues) ControlPaint.DrawFocusRectangle(e.Graphics,new Rectangle(7,7,Width-14,Height-14),ink,fill);
        }
    }
    internal sealed class LoadingBar : Control {
        public int Value; public bool Running; int step; readonly Timer clock=new Timer();
        public LoadingBar(){SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer,true);clock.Interval=35;clock.Tick+=delegate{if(Running&&Value<0){step=(step+5)%400;Invalidate();}};clock.Start();}
        protected override void Dispose(bool disposing){if(disposing)clock.Dispose();base.Dispose(disposing);}
        protected override void OnPaint(PaintEventArgs e){
            e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
            using(var track=Design.Round(new RectangleF(0,0,Width-1,Height-1),3))using(var b=new SolidBrush(Color.FromArgb(39,37,51))){e.Graphics.FillPath(b,track);e.Graphics.SetClip(track);
                if(Value>0)using(var fill=new LinearGradientBrush(ClientRectangle,Color.FromArgb(121,87,211),Design.Violet,0f))e.Graphics.FillRectangle(fill,0,0,Math.Max(2,Width*Math.Min(Value,100)/100),Height);
                else if(Running)using(var fill=new SolidBrush(Design.Violet))e.Graphics.FillRectangle(fill,(step/400f)*(Width+140)-140,0,140,Height);
            }
        }
    }
    internal sealed class Launcher : Form {
        [DllImport("user32.dll")] static extern bool ReleaseCapture();
        [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h,int m,IntPtr w,IntPtr l);
        readonly TextBox folder; readonly ActionButton browse,install,play;
        readonly Label status,percent; readonly LoadingBar progress; readonly ToolTip hints=new ToolTip();
        readonly Timer folderTimer=new Timer(); bool busy,ready,loadingFolder,detecting; string activeAction="";
        public Launcher(bool autoStatus){
            Text="Omnipotent"; ClientSize=new Size(880,590); FormBorderStyle=FormBorderStyle.None; MaximizeBox=false;
            StartPosition=FormStartPosition.CenterScreen; BackColor=Design.Background; ForeColor=Design.Ink; Font=new Font("Segoe UI",10);
            AutoScaleDimensions=new SizeF(96,96); AutoScaleMode=AutoScaleMode.Dpi; DoubleBuffered=true;
            var minimize=WindowButton("−",780);minimize.Click+=delegate{WindowState=FormWindowState.Minimized;};
            var close=WindowButton("×",826);close.Click+=delegate{Close();};
            folder=new TextBox{Location=new Point(66,365),Size=new Size(590,25),Font=new Font("Segoe UI",10.5f),BorderStyle=BorderStyle.None,BackColor=Design.Surface,ForeColor=Design.Ink,AccessibleName="Carpeta del juego",TabIndex=0};Controls.Add(folder);
            browse=new ActionButton{Text="Elegir carpeta",Location=new Point(676,350),Size=new Size(156,52),Font=new Font("Segoe UI",10),TabIndex=1,AccessibleName="Elegir carpeta del juego"};Controls.Add(browse);
            install=new ActionButton{Text="Instalar",Location=new Point(48,425),Size=new Size(253,62),TabIndex=2};Controls.Add(install);
            play=new ActionButton{Text="Play",Primary=true,Location=new Point(313,425),Size=new Size(519,62),Font=new Font("Segoe UI",15,FontStyle.Bold),TabIndex=3,Enabled=false};Controls.Add(play);
            status=new Label{Location=new Point(49,508),Size=new Size(705,35),Font=new Font("Segoe UI",9),ForeColor=Design.Muted,Text="Selecciona el juego para comenzar.",AutoEllipsis=true};Controls.Add(status);
            percent=new Label{Location=new Point(757,508),Size=new Size(74,22),Font=new Font("Segoe UI",9,FontStyle.Bold),ForeColor=Design.Violet,TextAlign=ContentAlignment.TopRight};Controls.Add(percent);
            progress=new LoadingBar{Location=new Point(49,550),Size=new Size(782,6),AccessibleName="Progreso de instalación"};Controls.Add(progress);
            loadingFolder=true;folder.Text=LoadFolder();loadingFolder=false;
            folderTimer.Interval=650;folderTimer.Tick+=delegate{folderTimer.Stop();if(!busy&&!detecting)RunAction("InspectSimple");};
            folder.TextChanged+=delegate{if(loadingFolder)return;ready=false;UpdateButtons();status.Text="Comprobando carpeta…";folderTimer.Stop();folderTimer.Start();};
            browse.Click+=delegate{using(var dialog=new FolderBrowserDialog{Description="Selecciona la carpeta de Call of Duty o cod25",ShowNewFolderButton=false}){if(Directory.Exists(folder.Text))dialog.SelectedPath=folder.Text;if(dialog.ShowDialog(this)==DialogResult.OK)folder.Text=ResolveGameFolder(dialog.SelectedPath);}};
            install.Click+=delegate{RunAction("InstallSimple");};play.Click+=delegate{RunAction("LaunchOffline");};
            FormClosing+=delegate(object s,FormClosingEventArgs e){if(busy){e.Cancel=true;status.Text=activeAction=="LaunchOffline"?"Cierra el juego antes de salir de Omnipotent.":"Espera a que termine la operación para cerrar.";}};
            UpdateButtons();
            Shown+=delegate{ActiveControl=install;folder.Select(0,0);if(autoStatus){if(GameDiscovery.Recognize(folder.Text)!=null)RunAction("InspectSimple");else DetectGame();}};
        }
        Button WindowButton(string text,int x){var b=new Button{Text=text,Location=new Point(x,12),Size=new Size(38,32),FlatStyle=FlatStyle.Flat,ForeColor=Design.Muted,BackColor=Design.Background,Font=new Font("Segoe UI",16),TabStop=false,AccessibleName=text=="×"?"Cerrar":"Minimizar"};b.FlatAppearance.BorderSize=0;b.FlatAppearance.MouseOverBackColor=Design.Surface;Controls.Add(b);return b;}
        protected override void OnMouseDown(MouseEventArgs e){base.OnMouseDown(e);if(e.Button==MouseButtons.Left&&e.Y<80){ReleaseCapture();SendMessage(Handle,0xA1,new IntPtr(2),IntPtr.Zero);}}
        void DrawText(Graphics g,string text,float size,FontStyle style,Color color,Rectangle rectangle){using(var f=new Font("Segoe UI",size,style))using(var b=new SolidBrush(color))g.DrawString(text,f,b,rectangle);}
        protected override void OnPaint(PaintEventArgs e){
            base.OnPaint(e);Graphics g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;g.ScaleTransform(ClientSize.Width/880f,ClientSize.Height/590f);
            using(var border=new Pen(Color.FromArgb(47,43,62)))g.DrawRectangle(border,0,0,879,589);
            using(var line=new Pen(Color.FromArgb(37,35,47)))g.DrawLine(line,48,76,832,76);
            using(var pen=new Pen(Design.Violet,2)){g.DrawPolygon(pen,new[]{new Point(49,32),new Point(60,25),new Point(71,32),new Point(71,45),new Point(60,52),new Point(49,45)});g.DrawLine(pen,55,35,60,32);g.DrawLine(pen,60,32,65,35);g.DrawLine(pen,60,32,60,45);}
            DrawText(g,"OMNIPOTENT",15,FontStyle.Bold,Design.Ink,new Rectangle(84,25,280,30));
            DrawText(g,"1.0",9,FontStyle.Regular,Design.Muted,new Rectangle(265,32,60,24));
            DrawText(g,"BLACK OPS 7  /  OFFLINE",9,FontStyle.Bold,Design.Violet,new Rectangle(48,106,400,24));
            DrawText(g,"Tu juego.\nA tu manera.",36,FontStyle.Bold,Design.Ink,new Rectangle(44,140,500,132));
            DrawText(g,"Instala. Desconecta. Juega.",11,FontStyle.Regular,Design.Muted,new Rectangle(49,277,500,30));
            // Original vector artwork: an orbital monolith, rendered locally.
            using(var glowPath=new GraphicsPath()){glowPath.AddEllipse(515,90,320,230);using(var glow=new PathGradientBrush(glowPath)){glow.CenterColor=Color.FromArgb(65,47,102);glow.SurroundColors=new[]{Design.Background};g.FillPath(glow,glowPath);}}
            var saved=g.Save();g.TranslateTransform(685,209);g.RotateTransform(-24);
            using(var orbit=new Pen(Color.FromArgb(84,68,118),1)){g.DrawEllipse(orbit,-139,-65,278,130);g.DrawEllipse(orbit,-119,-96,238,192);}
            using(var arc=new Pen(Color.FromArgb(175,148,236),2))g.DrawArc(arc,-139,-65,278,130,195,63);g.Restore(saved);
            Point[] outer={new Point(685,111),new Point(749,149),new Point(749,224),new Point(685,262),new Point(621,224),new Point(621,149)};
            using(var fill=new LinearGradientBrush(new Rectangle(621,111,128,151),Color.FromArgb(89,67,136),Color.FromArgb(24,23,37),45f))using(var edge=new Pen(Color.FromArgb(174,146,228),1.5f)){g.FillPolygon(fill,outer);g.DrawPolygon(edge,outer);}
            using(var pen=new Pen(Design.Violet,7)){g.DrawLines(pen,new[]{new Point(655,201),new Point(655,169),new Point(685,151),new Point(715,169),new Point(715,201),new Point(685,219),new Point(655,201)});g.DrawLine(pen,685,151,685,190);}
            using(var dot=new SolidBrush(Design.Violet)){g.FillEllipse(dot,800,164,5,5);g.FillEllipse(dot,574,252,4,4);}
            DrawText(g,"CARPETA DEL JUEGO",9,FontStyle.Bold,Design.Muted,new Rectangle(49,323,400,23));
            using(var path=Design.Round(new RectangleF(48,351,616,50),10))using(var fill=new SolidBrush(Design.Surface))using(var pen=new Pen(Color.FromArgb(46,44,60))){g.FillPath(fill,path);g.DrawPath(pen,path);}
        }
        public static string ResolveGameFolder(string input){string path=Engine.ValidateFolder(input);foreach(string relative in new[]{"cod25",@"Content\cod25"}){string candidate=Path.Combine(path,relative);if(Directory.Exists(candidate))return candidate;}return path;}
        string LoadFolder(){try{if(File.Exists(Program.SettingsPath)){var doc=new XmlDocument();doc.XmlResolver=null;doc.Load(Program.SettingsPath);var node=doc.SelectSingleNode("/umbral/gameFolder");if(node!=null)return node.InnerText;}}catch{}return Program.DefaultGame;}
        void SaveFolder(string game){using(var w=XmlWriter.Create(Program.SettingsPath,new XmlWriterSettings{Indent=true,Encoding=Encoding.UTF8})){w.WriteStartElement("umbral");w.WriteElementString("gameFolder",game);w.WriteEndElement();}}
        void DetectGame(){
            string original=folder.Text;detecting=true;UpdateButtons();Progress(-1,"Buscando Black Ops 7…");
            var worker=new BackgroundWorker();
            worker.DoWork+=delegate(object s,DoWorkEventArgs e){e.Result=GameDiscovery.Find(GameDiscovery.SystemLibraries());};
            worker.RunWorkerCompleted+=delegate(object s,RunWorkerCompletedEventArgs e){
                worker.Dispose();if(IsDisposed||Disposing)return;
                detecting=false;progress.Running=false;progress.Value=0;progress.Invalidate();percent.Text="";
                if(folder.Text!=original){UpdateButtons();if(!String.IsNullOrWhiteSpace(folder.Text))RunAction("InspectSimple");else status.Text="Selecciona el juego para comenzar.";return;}
                var matches=e.Error==null?(string[])e.Result:new string[0];
                if(matches.Length==1){loadingFolder=true;folder.Text=matches[0];loadingFolder=false;UpdateButtons();RunAction("InspectSimple");}
                else{loadingFolder=true;folder.Text="";loadingFolder=false;UpdateButtons();status.Text=matches.Length>1?"Hay varias instalaciones. Elige la carpeta que quieres usar.":"No se encontró el juego. Pulsa Elegir carpeta.";}
            };
            worker.RunWorkerAsync();
        }
        void UpdateButtons(){folder.Enabled=!busy;browse.Enabled=!busy;install.Enabled=!busy&&!detecting&&!String.IsNullOrWhiteSpace(folder.Text);play.Enabled=!busy&&!detecting&&ready;}
        void Progress(int value,string message){if(IsDisposed)return;progress.Value=value;progress.Running=true;progress.Invalidate();status.Text=message;percent.Text=value>=0?value+"%":"";}
        void RunAction(string action){
            if(busy)return;folderTimer.Stop();string game;
            try{game=ResolveGameFolder(folder.Text);if(!Directory.Exists(game))throw new IOException("Elige una carpeta existente para continuar.");loadingFolder=true;folder.Text=game;loadingFolder=false;SaveFolder(game);}
            catch(Exception ex){loadingFolder=false;ready=false;status.Text=ex.Message;UpdateButtons();return;}
            busy=true;activeAction=action;UpdateButtons();status.ForeColor=Design.Muted;
            Progress(-1,action=="InstallSimple"?"Preparando instalación…":action=="LaunchOffline"?"Abriendo el juego…":"Comprobando instalación…");
            if(action=="LaunchOffline")play.Text="En juego";
            var worker=new BackgroundWorker{WorkerReportsProgress=true};
            worker.DoWork+=delegate(object s,DoWorkEventArgs e){e.Result=Engine.Run(action,game,false,delegate(int value,string message){worker.ReportProgress(value,message);});};
            worker.ProgressChanged+=delegate(object s,ProgressChangedEventArgs e){Progress(e.ProgressPercentage,Convert.ToString(e.UserState));};
            worker.RunWorkerCompleted+=delegate(object s,RunWorkerCompletedEventArgs e){
                var result=e.Error==null?(EngineResult)e.Result:EngineResult.Failure(e.Error.Message);busy=false;play.Text="Play";progress.Running=false;
                ready=result.Allows("LaunchOffline");
                if(result.Ok){if(action=="InstallSimple"){ready=true;Progress(100,"Instalación completa. Todo listo para jugar.");progress.Running=false;}else if(action=="LaunchOffline"){status.Text="Todo listo para tu próxima partida.";percent.Text="";progress.Value=0;}else{status.Text=ready?"Todo listo para jugar.":"Instala el modo offline para comenzar.";percent.Text="";progress.Value=0;}}
                else{ready=false;status.ForeColor=Color.FromArgb(242,180,166);status.Text=FriendlyError(result.Message);percent.Text="";progress.Value=0;}
                hints.SetToolTip(status,result.Ok?"":result.Message);progress.Invalidate();UpdateButtons();
                try{File.WriteAllText(Path.Combine(Bundle.IsEmbedded?Bundle.Home:Program.Root,"ultima-operacion.txt"),result.Report(),Encoding.UTF8);}catch{}
                worker.Dispose();
            };worker.RunWorkerAsync();
        }
        public void PreviewState(string state){
            ActiveControl=null;folder.Select(0,0);
            if(state=="ready"){ready=true;status.Text="Todo listo para jugar.";UpdateButtons();}
            if(state=="installing"){busy=true;UpdateButtons();Progress(58,"Guardando respaldo…");}
            if(state=="error"){ready=false;UpdateButtons();status.ForeColor=Color.FromArgb(242,180,166);status.Text="No se pudo completar la instalación. Comprueba la carpeta y vuelve a intentarlo.";}
        }
        static string FriendlyError(string message){if(String.IsNullOrWhiteSpace(message))return "No se pudo completar la operación. Vuelve a intentarlo.";if(message.Contains("Cierra el juego"))return "Cierra el juego y vuelve a intentarlo.";if(message.Contains("paquete ausente")||message.Contains("Archivo modificado"))return "Faltan archivos o necesitan reparación. Pulsa Instalar.";if(message.Contains("otra instalacion"))return "El respaldo pertenece a otra carpeta. Selecciona la instalación original.";string line=message.Split(new[]{'\r','\n'},StringSplitOptions.RemoveEmptyEntries)[0];return line.Length>160?line.Substring(0,157)+"…":line;}
        protected override void Dispose(bool disposing){if(disposing){folderTimer.Dispose();hints.Dispose();}base.Dispose(disposing);}
    }
}
