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
        public static readonly Color Background = Color.FromArgb(17,18,20), Surface = Color.FromArgb(25,27,30), Ink = Color.FromArgb(240,241,243), Muted = Color.FromArgb(143,147,154), Violet = Color.FromArgb(230,232,236);
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
            e.Graphics.Clear(BackColor);e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
            Color fill=Primary?(Enabled?(hover?Color.White:Design.Violet):Color.FromArgb(49,51,55)):(hover&&Enabled?Color.FromArgb(34,37,41):Design.Surface);
            using(var path=Design.Round(new RectangleF(1,1,Width-3,Height-3),8))using(var brush=new SolidBrush(fill))using(var pen=new Pen(Primary?fill:Color.FromArgb(54,57,63))){e.Graphics.FillPath(brush,path);e.Graphics.DrawPath(pen,path);}
            Color ink=Enabled?(Primary?Color.FromArgb(20,22,25):Design.Ink):Color.FromArgb(115,119,125);
            TextRenderer.DrawText(e.Graphics,Text,Font,ClientRectangle,ink,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);
            if(Focused&&ShowFocusCues) ControlPaint.DrawFocusRectangle(e.Graphics,new Rectangle(7,7,Width-14,Height-14),ink,fill);
        }
    }
    internal sealed class LoadingBar : Control {
        public int Value; public bool Running; int step; readonly Timer clock=new Timer();
        public LoadingBar(){SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer,true);clock.Interval=35;clock.Tick+=delegate{if(Running&&Value<0){step=(step+5)%400;Invalidate();}};clock.Start();}
        protected override void Dispose(bool disposing){if(disposing)clock.Dispose();base.Dispose(disposing);}
        protected override void OnPaint(PaintEventArgs e){
            e.Graphics.Clear(BackColor);e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
            using(var track=Design.Round(new RectangleF(0,0,Width-1,Height-1),3))using(var b=new SolidBrush(Color.FromArgb(39,41,45))){e.Graphics.FillPath(b,track);e.Graphics.SetClip(track);
                if(Value>0)using(var fill=new LinearGradientBrush(ClientRectangle,Color.FromArgb(151,159,170),Design.Violet,0f))e.Graphics.FillRectangle(fill,0,0,Math.Max(2,Width*Math.Min(Value,100)/100),Height);
                else if(Running)using(var fill=new SolidBrush(Design.Violet))e.Graphics.FillRectangle(fill,(step/400f)*(Width+140)-140,0,140,Height);
            }
        }
    }
    internal sealed class Launcher : Form {
        [DllImport("user32.dll")] static extern bool ReleaseCapture();
        [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h,int m,IntPtr w,IntPtr l);
        readonly TextBox folder; readonly ActionButton browse,install,play,openTrainer;
        readonly Button gameTab,modsTab;
        readonly Label status,percent,modStatus,modPercent; readonly LoadingBar progress,modProgress; readonly ToolTip hints=new ToolTip();
        readonly Timer folderTimer=new Timer(); bool busy,ready,loadingFolder,detecting,modsSelected,trainerBusy; string activeAction="";
        public Launcher(bool autoStatus){
            Text="omnipotent by kaly"; ClientSize=new Size(760,420); FormBorderStyle=FormBorderStyle.None; MaximizeBox=false;
            StartPosition=FormStartPosition.CenterScreen; BackColor=Design.Background; ForeColor=Design.Ink; Font=new Font("Segoe UI",10);
            AutoScaleDimensions=new SizeF(96,96); AutoScaleMode=AutoScaleMode.Dpi; DoubleBuffered=true;
            var minimize=WindowButton("−",660);minimize.Click+=delegate{WindowState=FormWindowState.Minimized;};
            var close=WindowButton("×",706);close.Click+=delegate{Close();};
            gameTab=Navigation("Juego",32);modsTab=Navigation("Mods",120);
            gameTab.Click+=delegate{SelectTab(false);};modsTab.Click+=delegate{SelectTab(true);};
            folder=new TextBox{Location=new Point(46,207),Size=new Size(510,24),Font=new Font("Segoe UI",10),BorderStyle=BorderStyle.None,BackColor=Design.Surface,ForeColor=Design.Ink,AccessibleName="Carpeta del juego",TabIndex=2};Controls.Add(folder);
            browse=new ActionButton{Text="Elegir carpeta",Location=new Point(578,194),Size=new Size(150,48),Font=new Font("Segoe UI",10),TabIndex=3,AccessibleName="Elegir carpeta del juego"};Controls.Add(browse);
            install=new ActionButton{Text="Instalar",Location=new Point(32,266),Size=new Size(216,54),TabIndex=4};Controls.Add(install);
            play=new ActionButton{Text="Play",Primary=true,Location=new Point(260,266),Size=new Size(468,54),Font=new Font("Segoe UI",12,FontStyle.Bold),TabIndex=5,Enabled=false};Controls.Add(play);
            status=Footer("Selecciona el juego para comenzar.");percent=Percentage();
            progress=Bar();
            openTrainer=new ActionButton{Text="Abrir trainer",Primary=true,Location=new Point(32,266),Size=new Size(696,54),TabIndex=6,AccessibleName="Abrir trainer de Zombies"};Controls.Add(openTrainer);
            modStatus=Footer("Se descarga una vez. Después puedes abrirlo sin internet.");modPercent=Percentage();modProgress=Bar();
            openTrainer.Click+=delegate{OpenTrainer();};
            loadingFolder=true;folder.Text=LoadFolder();loadingFolder=false;
            folderTimer.Interval=650;folderTimer.Tick+=delegate{folderTimer.Stop();if(!busy&&!detecting)RunAction("InspectSimple");};
            folder.TextChanged+=delegate{if(loadingFolder)return;ready=false;UpdateButtons();status.Text="Comprobando carpeta…";folderTimer.Stop();folderTimer.Start();};
            browse.Click+=delegate{using(var dialog=new FolderBrowserDialog{Description="Selecciona la carpeta de Call of Duty o cod25",ShowNewFolderButton=false}){if(Directory.Exists(folder.Text))dialog.SelectedPath=folder.Text;if(dialog.ShowDialog(this)==DialogResult.OK)folder.Text=ResolveGameFolder(dialog.SelectedPath);}};
            install.Click+=delegate{RunAction("InstallSimple");};play.Click+=delegate{RunAction("LaunchOffline");};
            FormClosing+=delegate(object s,FormClosingEventArgs e){if(busy||trainerBusy){e.Cancel=true;if(trainerBusy)modStatus.Text="Espera a que termine de abrir el trainer.";else status.Text=activeAction=="LaunchOffline"?"Cierra el juego antes de salir de Omnipotent.":"Espera a que termine la operación para cerrar.";}};
            SelectTab(false);UpdateButtons();
            Shown+=delegate{ActiveControl=gameTab;folder.Select(0,0);if(autoStatus){if(GameDiscovery.Recognize(folder.Text)!=null)RunAction("InspectSimple");else DetectGame();}};
        }
        Label Footer(string text){var label=new Label{Location=new Point(33,345),Size=new Size(615,34),Font=new Font("Segoe UI",9),ForeColor=Design.Muted,Text=text,AutoEllipsis=true};Controls.Add(label);return label;}
        Label Percentage(){var label=new Label{Location=new Point(654,345),Size=new Size(73,23),Font=new Font("Segoe UI",9),ForeColor=Design.Ink,TextAlign=ContentAlignment.TopRight};Controls.Add(label);return label;}
        LoadingBar Bar(){var bar=new LoadingBar{Location=new Point(33,389),Size=new Size(694,4),AccessibleName="Progreso"};Controls.Add(bar);return bar;}
        Button Navigation(string text,int x){var b=new Button{Text=text,Location=new Point(x,94),Size=new Size(76,38),FlatStyle=FlatStyle.Flat,BackColor=Design.Background,ForeColor=Design.Muted,Font=new Font("Segoe UI",10),Cursor=Cursors.Hand,TabIndex=text=="Juego"?0:1};b.FlatAppearance.BorderSize=0;b.FlatAppearance.MouseOverBackColor=Design.Surface;Controls.Add(b);return b;}
        void SelectTab(bool mods){
            modsSelected=mods;
            foreach(Control c in new Control[]{folder,browse,install,play,status,percent,progress})c.Visible=!mods;
            foreach(Control c in new Control[]{openTrainer,modStatus,modPercent,modProgress})c.Visible=mods;
            gameTab.ForeColor=mods?Design.Muted:Design.Ink;modsTab.ForeColor=mods?Design.Ink:Design.Muted;
            gameTab.AccessibleDescription=mods?"":"Pestaña seleccionada";modsTab.AccessibleDescription=mods?"Pestaña seleccionada":"";Invalidate();
        }
        void OpenTrainer(){
            if(trainerBusy)return;trainerBusy=true;UpdateButtons();modStatus.ForeColor=Design.Muted;modStatus.Text="Preparando trainer…";modProgress.Value=-1;modProgress.Running=true;
            string game=GameDiscovery.Recognize(folder.Text);
            var worker=new BackgroundWorker{WorkerReportsProgress=true};
            worker.DoWork+=delegate{Trainer.Open(game,delegate(int value,string message){worker.ReportProgress(value,message);});};
            worker.ProgressChanged+=delegate(object s,ProgressChangedEventArgs e){modProgress.Value=e.ProgressPercentage;modProgress.Invalidate();modPercent.Text=e.ProgressPercentage+"%";modStatus.Text=Convert.ToString(e.UserState);};
            worker.RunWorkerCompleted+=delegate(object s,RunWorkerCompletedEventArgs e){
                trainerBusy=false;modProgress.Running=false;modPercent.Text="";modProgress.Value=0;modProgress.Invalidate();
                modStatus.Text=e.Error==null?"Trainer abierto. Prepara el juego desde el trainer antes de la primera partida.":FriendlyError(e.Error.Message);
                if(e.Error!=null)modStatus.ForeColor=Color.FromArgb(242,180,166);
                hints.SetToolTip(modStatus,e.Error==null?"":e.Error.Message);UpdateButtons();worker.Dispose();
            };worker.RunWorkerAsync();
        }
        Button WindowButton(string text,int x){var b=new Button{Text=text,Location=new Point(x,16),Size=new Size(34,28),FlatStyle=FlatStyle.Flat,ForeColor=Design.Muted,BackColor=Design.Background,Font=new Font("Segoe UI",13),TabStop=false,AccessibleName=text=="×"?"Cerrar":"Minimizar"};b.FlatAppearance.BorderSize=0;b.FlatAppearance.MouseOverBackColor=Design.Surface;Controls.Add(b);return b;}
        protected override void OnMouseDown(MouseEventArgs e){base.OnMouseDown(e);if(e.Button==MouseButtons.Left&&e.Y<80){ReleaseCapture();SendMessage(Handle,0xA1,new IntPtr(2),IntPtr.Zero);}}
        void DrawText(Graphics g,string text,float size,FontStyle style,Color color,Rectangle rectangle){using(var f=new Font("Segoe UI",size,style))using(var b=new SolidBrush(color))g.DrawString(text,f,b,rectangle);}
        protected override void OnPaint(PaintEventArgs e){
            base.OnPaint(e);Graphics g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;g.ScaleTransform(ClientSize.Width/760f,ClientSize.Height/420f);
            using(var border=new Pen(Color.FromArgb(47,49,53)))g.DrawRectangle(border,0,0,759,419);
            DrawText(g,"omnipotent",24,FontStyle.Bold,Design.Ink,new Rectangle(28,30,230,48));
            DrawText(g,"by kaly",11,FontStyle.Regular,Design.Muted,new Rectangle(236,47,140,28));
            using(var line=new Pen(Color.FromArgb(42,44,48)))g.DrawLine(line,32,137,728,137);
            using(var line=new Pen(Design.Ink,2))g.DrawLine(line,modsSelected?120:32,137,modsSelected?196:108,137);
            if(!modsSelected){
                DrawText(g,"Carpeta del juego",10,FontStyle.Regular,Design.Muted,new Rectangle(30,164,400,26));
                using(var path=Design.Round(new RectangleF(32,195,534,46),7))using(var fill=new SolidBrush(Design.Surface))using(var pen=new Pen(Color.FromArgb(54,57,63))){g.FillPath(fill,path);g.DrawPath(pen,path);}
            }else{
                DrawText(g,"Trainer Zombies",18,FontStyle.Bold,Design.Ink,new Rectangle(29,167,600,38));
                DrawText(g,"Black Ops 7 · Partida individual offline",10,FontStyle.Regular,Design.Muted,new Rectangle(31,213,650,29));
            }
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
        void UpdateButtons(){folder.Enabled=!busy&&!trainerBusy;browse.Enabled=!busy&&!trainerBusy;install.Enabled=!busy&&!trainerBusy&&!detecting&&!String.IsNullOrWhiteSpace(folder.Text);play.Enabled=!busy&&!trainerBusy&&!detecting&&ready;openTrainer.Enabled=!trainerBusy&&(!busy||activeAction=="LaunchOffline");openTrainer.Text=trainerBusy?"Abriendo…":"Abrir trainer";}
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
            ActiveControl=null;folder.Select(0,0);if(state=="mods")SelectTab(true);
            if(state=="ready"){ready=true;status.Text="Todo listo para jugar.";UpdateButtons();}
            if(state=="installing"){busy=true;UpdateButtons();Progress(58,"Guardando respaldo…");}
            if(state=="error"){ready=false;UpdateButtons();status.ForeColor=Color.FromArgb(242,180,166);status.Text="No se pudo completar la instalación. Comprueba la carpeta y vuelve a intentarlo.";}
        }
        static string FriendlyError(string message){if(String.IsNullOrWhiteSpace(message))return "No se pudo completar la operación. Vuelve a intentarlo.";if(message.Contains("Cierra el juego"))return "Cierra el juego y vuelve a intentarlo.";if(message.Contains("paquete ausente")||message.Contains("Archivo modificado"))return "Faltan archivos o necesitan reparación. Pulsa Instalar.";if(message.Contains("otra instalacion"))return "El respaldo pertenece a otra carpeta. Selecciona la instalación original.";string line=message.Split(new[]{'\r','\n'},StringSplitOptions.RemoveEmptyEntries)[0];return line.Length>160?line.Substring(0,157)+"…":line;}
        protected override void Dispose(bool disposing){if(disposing){folderTimer.Dispose();hints.Dispose();}base.Dispose(disposing);}
    }
}
