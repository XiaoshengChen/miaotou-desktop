using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using Microsoft.Win32;
using Forms=System.Windows.Forms;

namespace Miaotou;
public static class Program {
    [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern IntPtr FindWindow(string? cls,string name);
    [DllImport("user32.dll")]static extern IntPtr SendMessage(IntPtr handle,int message,IntPtr w,IntPtr l);
    [STAThread]public static void Main(string[] args) {
        Forms.Application.SetHighDpiMode(Forms.HighDpiMode.PerMonitorV2);
        using var mutex=new Mutex(true,"Local\\MiaotouOneThing",out bool first);
        if(!first){var h=FindWindow(null,"小苗头");if(h!=IntPtr.Zero)SendMessage(h,0x8025,IntPtr.Zero,IntPtr.Zero);return;}
        var app=new System.Windows.Application{ShutdownMode=ShutdownMode.OnExplicitShutdown};
        app.DispatcherUnhandledException+=(s,e)=>{System.Windows.MessageBox.Show("Something went wrong. Your last saved record is safe. / 暂时遇到问题，已保存的记录还在。","小苗头");e.Handled=true;};
        var window=new MainWindow(args.Contains("--demo"));app.Run(window);
    }
}
public sealed class MainWindow:Window {
    static readonly SolidColorBrush Ink=Brush("#173F3B"),Aqua=Brush("#A4CDC6"),Mint=Brush("#DAEAE4"),Paper=Brush("#FAFCFA"),Muted=Brush("#5E746B");
    readonly Disk disk;Document document=new();bool writable,quitting,rendering,composing,controls;string route="home";Thing? completed;
    string draft="";string? toast;Forms.NotifyIcon tray=null!;DispatcherTimer dayTimer;DispatcherTimer? toastTimer;
    TextBlock? currentTip;TextBox? editor;Fireworks? fireworks;Point? beforeDrag;
    bool Zh=>document.State.Language=="zh";
    string T(string en,string zh)=>Zh?zh:en;
    public MainWindow(bool demo) {
        Title="小苗头";Width=360;Height=270;WindowStyle=WindowStyle.None;ResizeMode=ResizeMode.NoResize;
        AllowsTransparency=true;Background=Brushes.Transparent;ShowInTaskbar=false;FontFamily=new FontFamily("Segoe UI, Microsoft YaHei UI");
        var folder=demo?Path.Combine(Path.GetTempPath(),"Miaotou-Windows-Demo"):Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Miaotou");
        disk=new Disk(folder);
        try {document=disk.Load();writable=true;if(demo&&document.State.Active==null){document.State.Language="zh";document.State.Save("上线我的第一个网站");disk.Write(document);}}
        catch{System.Windows.MessageBox.Show("Could not open saved data. The original file is preserved. / 无法读取记录，原文件已保留。","小苗头");}
        SourceInitialized+=(s,e)=>HwndSource.FromHwnd(new WindowInteropHelper(this).Handle)?.AddHook(WindowMessage);
        Loaded+=(s,e)=>{Clamp();};LocationChanged+=(s,e)=>{if(!rendering&&IsLoaded&&beforeDrag==null)SavePosition();};
        Closing+=(s,e)=>{if(!quitting){e.Cancel=true;Hide();}};
        BuildTray();Topmost=document.Preferences.Pinned;Render();
        var area=SystemParameters.WorkArea;Left=document.Preferences.X??area.Right-Width-24;Top=document.Preferences.Y??area.Top+32;
        dayTimer=new DispatcherTimer{Interval=TimeSpan.FromSeconds(30)};dayTimer.Tick+=(s,e)=>{if(currentTip!=null)currentTip.Text=Tips.Line(document.State);};dayTimer.Start();
    }
    IntPtr WindowMessage(IntPtr h,int m,IntPtr w,IntPtr l,ref bool handled){if(m==0x8025){ShowCard();handled=true;}return IntPtr.Zero;}
    static SolidColorBrush Brush(string hex)=>new((Color)ColorConverter.ConvertFromString(hex));
    static TextBlock Text(string text,double size=13,Brush? color=null)=>new(){Text=text,FontSize=size,Foreground=color??Ink,TextWrapping=TextWrapping.Wrap};
    static StackPanel Stack()=>new(){Orientation=Orientation.Vertical};
    static Button Button(string title,Action action,bool primary=false){var b=new Button{Content=title,FontSize=13,Padding=new Thickness(12,8,12,8),Margin=new Thickness(0,4,0,4),Background=primary?Ink:Brushes.Transparent,Foreground=primary?Paper:Ink,BorderThickness=new Thickness(0),Cursor=Cursors.Hand,MinHeight=32};
        var border=new FrameworkElementFactory(typeof(Border));border.SetValue(Border.CornerRadiusProperty,new CornerRadius(primary?19:6));border.SetValue(Border.BackgroundProperty,new TemplateBindingExtension(Control.BackgroundProperty));border.SetValue(Border.PaddingProperty,new TemplateBindingExtension(Control.PaddingProperty));
        var content=new FrameworkElementFactory(typeof(ContentPresenter));content.SetValue(FrameworkElement.HorizontalAlignmentProperty,HorizontalAlignment.Center);content.SetValue(FrameworkElement.VerticalAlignmentProperty,VerticalAlignment.Center);border.AppendChild(content);b.Template=new ControlTemplate(typeof(Button)){VisualTree=border};b.Click+=(s,e)=>action();return b;}
    Image Mascot(bool happy=false,double width=34,double height=25) {
        var uri=new Uri("pack://application:,,,/Assets/"+(happy?"happy":"companion")+".png");
        var bitmap=new BitmapImage(uri);
        if(!happy)return new Image{Source=bitmap,Width=width,Height=height,Stretch=Stretch.Uniform};
        var src=new FormatConvertedBitmap(bitmap,PixelFormats.Bgra32,null,0);int stride=src.PixelWidth*4;byte[] pixels=new byte[stride*src.PixelHeight];src.CopyPixels(pixels,stride,0);
        for(int i=0;i<pixels.Length;i+=4){byte alpha=(byte)(pixels[i]*0.0722+pixels[i+1]*0.7152+pixels[i+2]*0.2126);pixels[i]=59;pixels[i+1]=63;pixels[i+2]=23;pixels[i+3]=alpha;}
        var output=BitmapSource.Create(src.PixelWidth,src.PixelHeight,96,96,PixelFormats.Bgra32,null,pixels,stride);output.Freeze();
        return new Image{Source=output,Width=width,Height=height,Stretch=Stretch.Uniform};
    }
    void BuildTray(){
        using var stream=System.Windows.Application.GetResourceStream(new Uri("pack://application:,,,/Assets/Miaotou.ico"))!.Stream;
        tray=new Forms.NotifyIcon{Icon=new System.Drawing.Icon(stream),Visible=true,Text="小苗头"};
        tray.MouseClick+=(s,e)=>{if(e.Button==Forms.MouseButtons.Left)Dispatcher.Invoke(ShowCard);};RefreshTray();
    }
    void RefreshTray(){
        string value=document.State.Active?.Text??T("One thing you want to do","写一件想做的事");tray.Text=("小苗头 · "+value).Length>63?("小苗头 · "+value)[..60]+"…":"小苗头 · "+value;
        var menu=new Forms.ContextMenuStrip();void Item(string text,Action action)=>menu.Items.Add(text,null,(s,e)=>Dispatcher.Invoke(action));
        Item(T("Show card","显示卡片"),ShowCard);Item(T("History","历史记录"),()=>{route="history";ShowCard();});
        Item(T("Preferences","偏好设置"),()=>{route="settings";ShowCard();});menu.Items.Add(new Forms.ToolStripSeparator());
        Item(T("Quit 小苗头","退出小苗头"),()=>{quitting=true;tray.Visible=false;tray.Dispose();System.Windows.Application.Current.Shutdown();});
        var old=tray.ContextMenuStrip;tray.ContextMenuStrip=menu;old?.Dispose();
    }
    void ShowCard(){Show();if(document.Preferences.Collapsed){document.Preferences.Collapsed=false;Persist(document);}Render();Activate();}
    bool Persist(Document next){
        if(!writable)return false;
        try{disk.Write(next);document=next;RefreshTray();return true;}
        catch{System.Windows.MessageBox.Show(T("Could not save. Your previous record is safe.","暂时无法保存，原来的记录还在。"),"小苗头");return false;}
    }
    void SavePosition(){var next=Disk.Copy(document);next.Preferences.X=Left;next.Preferences.Y=Top;Persist(next);}
    void Clamp(){
        // Work-area clamping uses device-independent pixels, including multi-monitor layouts.
        var screen=Forms.Screen.FromHandle(new WindowInteropHelper(this).Handle);var dpi=VisualTreeHelper.GetDpi(this);
        var a=screen.WorkingArea;double minX=a.Left/dpi.DpiScaleX,minY=a.Top/dpi.DpiScaleY,maxX=a.Right/dpi.DpiScaleX,maxY=a.Bottom/dpi.DpiScaleY;
        Left=Math.Clamp(Left,minX,Math.Max(minX,maxX-Width));Top=Math.Clamp(Top,minY,Math.Max(minY,maxY-Height));
    }
    void StartDrag(object s,MouseButtonEventArgs e){
        if(e.ChangedButton!=MouseButton.Left)return;
        if(e.OriginalSource is System.Windows.Controls.Primitives.ButtonBase||e.OriginalSource is TextBox)return;
        beforeDrag=new Point(Left,Top);try{DragMove();}catch(InvalidOperationException){}finally{beforeDrag=null;SavePosition();}e.Handled=true;
    }
    void Render(){
        rendering=true;fireworks?.Stop();fireworks=null;currentTip=null;editor=null;
        var body=Stack();bool strip=document.Preferences.Collapsed&&document.State.Active!=null&&completed==null&&route=="home";
        Width=strip?280:360;Height=strip?44:310;
        var shell=new Border{CornerRadius=new CornerRadius(14),Background=Paper,Child=body,ClipToBounds=true};shell.SizeChanged+=(s,e)=>shell.Clip=new RectangleGeometry(new Rect(0,0,shell.ActualWidth,shell.ActualHeight),14,14);Content=shell;
        if(strip){
            var row=new DockPanel{Height=44,Background=Aqua,Margin=new Thickness(0)};
            var expand=Button("⌄",()=>{var next=Disk.Copy(document);next.Preferences.Collapsed=false;Persist(next);Render();});expand.Width=32;DockPanel.SetDock(expand,Dock.Right);row.Children.Add(expand);
            var image=Mascot(false,25,20);image.Margin=new Thickness(12,0,8,0);DockPanel.SetDock(image,Dock.Left);row.Children.Add(image);
            var title=Text(document.State.Active!.Text,13);title.TextTrimming=TextTrimming.CharacterEllipsis;title.TextWrapping=TextWrapping.NoWrap;title.VerticalAlignment=VerticalAlignment.Center;row.Children.Add(title);row.MouseLeftButtonDown+=StartDrag;body.Children.Add(row);
        } else {
            var head=new DockPanel{Height=38,Margin=new Thickness(14,0,10,0)};
            var menu=Button("···",OpenMenu);menu.Width=30;DockPanel.SetDock(menu,Dock.Right);head.Children.Add(menu);
            var collapse=Button("−",()=>{if(document.State.Active!=null&&route=="home"&&completed==null){var next=Disk.Copy(document);next.Preferences.Collapsed=true;Persist(next);Render();}else Hide();});collapse.Width=28;DockPanel.SetDock(collapse,Dock.Right);head.Children.Add(collapse);
            var pin=Button("\uE718",()=>{var next=Disk.Copy(document);next.Preferences.Pinned=!next.Preferences.Pinned;if(Persist(next)){Topmost=next.Preferences.Pinned;Render();}});pin.FontFamily=new FontFamily("Segoe Fluent Icons");pin.Padding=new Thickness(4);pin.Width=28;pin.Opacity=document.Preferences.Pinned?1:.5;pin.ToolTip=T("Keep above windows","保持置顶");DockPanel.SetDock(pin,Dock.Right);head.Children.Add(pin);
            var name=Text(route is "home" or "write"?"小苗头":"‹  小苗头",12);name.FontWeight=FontWeights.SemiBold;name.VerticalAlignment=VerticalAlignment.Center;if(route is not "home" and not "write")name.MouseLeftButtonUp+=(s,e)=>{route="home";Render();};head.Children.Add(name);head.MouseLeftButtonDown+=StartDrag;body.Children.Add(head);
            if(completed!=null)Celebration(body);else if(route=="history")History(body);else if(route=="settings")Settings(body);else if(route=="about")About(body);else if(route=="write"||document.State.Active==null)Editor(body);else Active(body);
        }
        Topmost=document.Preferences.Pinned;rendering=false;if(IsLoaded)Clamp();
    }
    void OpenMenu(){
        var menu=new ContextMenu();void Item(string text,Action a,bool enabled=true){var i=new MenuItem{Header=text,IsEnabled=enabled};i.Click+=(s,e)=>a();menu.Items.Add(i);}
        Item(T("Replace thing","换一件"),()=>{route="write";draft="";Render();},document.State.Active!=null);
        Item(T("History","历史记录"),()=>{route="history";Render();});Item(T("Preferences","偏好设置"),()=>{route="settings";Render();});Item(T("About","关于"),()=>{route="about";Render();});
        menu.Items.Add(new Separator());Item(T("Hide card","隐藏卡片"),Hide);Item(T("Quit 小苗头","退出小苗头"),()=>{quitting=true;tray.Dispose();System.Windows.Application.Current.Shutdown();});menu.IsOpen=true;
    }
    void Active(StackPanel body){
        Height=(document.State.CompanionEnabled?212:150)+(controls?72:0);
        var title=Text(document.State.Active!.Text,28);title.FontWeight=FontWeights.Medium;title.TextAlignment=TextAlignment.Center;title.VerticalAlignment=VerticalAlignment.Center;title.Margin=new Thickness(20,10,20,10);
        var top=new Border{Height=112,Background=Aqua,Child=title};top.MouseLeftButtonDown+=(s,e)=>{var origin=new Point(Left,Top);StartDrag(s,e);if(Math.Abs(Left-origin.X)+Math.Abs(Top-origin.Y)<3){controls=!controls;Render();}};body.Children.Add(top);
        if(document.State.CompanionEnabled){var row=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Center,VerticalAlignment=VerticalAlignment.Center};row.Children.Add(Mascot());currentTip=Text(Tips.Line(document.State),12);currentTip.TextWrapping=TextWrapping.NoWrap;currentTip.TextTrimming=TextTrimming.CharacterEllipsis;currentTip.MaxWidth=280;currentTip.Margin=new Thickness(8,0,0,0);currentTip.VerticalAlignment=VerticalAlignment.Center;row.Children.Add(currentTip);body.Children.Add(new Border{Height=62,Background=Mint,Child=row});}
        if(controls){var done=Button(T("Done","完成"),()=>{var next=Disk.Copy(document);var old=next.State.Complete();if(old!=null&&Persist(next)){completed=old;controls=false;Render();}},true);done.Margin=new Thickness(24,14,24,14);body.Children.Add(done);}
    }
    string Placeholder()=>document.State.History.Count(h=>h.Completed)==0?T("One thing you want to do","写一件想做的事"):T("What's the next thing?","想做的下一件事是什么？");
    void Editor(StackPanel body){
        Height=(toast==null?300:344)+(document.State.Active!=null?42:0);var box=Stack();box.Margin=new Thickness(24,8,24,20);
        if(document.State.Active!=null)box.Children.Add(Button(T("Cancel","取消"),()=>{route="home";draft="";toast=null;Render();}));
        var grid=new Grid{MinHeight=90,MaxHeight=110};var prompt=Text(Placeholder(),28,Brush("#909E96"));prompt.IsHitTestVisible=false;prompt.VerticalAlignment=VerticalAlignment.Center;grid.Children.Add(prompt);
        editor=new TextBox{Text=draft,FontSize=28,Foreground=Ink,Background=Brushes.Transparent,BorderThickness=new Thickness(0),TextWrapping=TextWrapping.Wrap,AcceptsReturn=false,VerticalContentAlignment=VerticalAlignment.Center,MaxHeight=110,VerticalScrollBarVisibility=ScrollBarVisibility.Auto};
        var counter=Text("",11,Brushes.IndianRed);counter.HorizontalAlignment=HorizontalAlignment.Right;
        void Count(){int n=Budget.Count(editor.Text)-Budget.Limit(editor.Text);counter.Text=n>0?"-"+n:"";prompt.Visibility=editor.Text.Length==0?Visibility.Visible:Visibility.Collapsed;}
        editor.TextChanged+=(s,e)=>{draft=editor.Text;Count();};editor.KeyDown+=(s,e)=>{if(e.Key==Key.Enter&&!composing){Save();e.Handled=true;}};
        TextCompositionManager.AddPreviewTextInputStartHandler(editor,(s,e)=>composing=true);TextCompositionManager.AddPreviewTextInputHandler(editor,(s,e)=>composing=false);grid.Children.Add(editor);Count();box.Children.Add(grid);
        box.Children.Add(new Border{Height=1,Background=Muted,Opacity=.45});
        var explanation=new DockPanel{Margin=new Thickness(0,8,0,8)};DockPanel.SetDock(counter,Dock.Right);explanation.Children.Add(counter);explanation.Children.Add(Text(T("Give it a place you'll see every day.","给真正想做的事，留一个每天看得见的位置。"),11,Muted));box.Children.Add(explanation);
        if(toast!=null)box.Children.Add(new Border{Background=Mint,CornerRadius=new CornerRadius(8),Padding=new Thickness(10),Child=Text(toast,12)});
        var save=Button(T("Save this","写好了"),Save,true);save.Margin=new Thickness(0,14,0,0);box.Children.Add(save);body.Children.Add(box);
    }
    void Save(){
        if(composing){editor?.MoveFocus(new TraversalRequest(FocusNavigationDirection.Next));composing=false;Dispatcher.BeginInvoke(new Action(Save),DispatcherPriority.Input);return;}
        string text=Budget.Normalize(draft);
        var formatted=new FormattedText(text,CultureInfo.CurrentCulture,FlowDirection.LeftToRight,new Typeface(FontFamily,FontStyles.Normal,FontWeights.Medium,FontStretches.Normal),28,Ink,VisualTreeHelper.GetDpi(this).PixelsPerDip){MaxTextWidth=312};
        if(!Budget.Valid(text)||formatted.Height>74){toast=T("Keep it simple. Try fewer words.","简单说就好，再短一点试试。");Render();toastTimer?.Stop();toastTimer=new DispatcherTimer{Interval=TimeSpan.FromSeconds(3)};toastTimer.Tick+=(s,e)=>{toastTimer.Stop();toast=null;if(route=="write"||document.State.Active==null)Render();};toastTimer.Start();return;}
        var next=Disk.Copy(document);next.State.Save(text);if(Persist(next)){draft="";toast=null;route="home";completed=null;Render();}
    }
    void Celebration(StackPanel body){
        Height=365;var area=new Grid{Height=235};fireworks=new Fireworks();area.Children.Add(fireworks);
        var center=Stack();center.VerticalAlignment=VerticalAlignment.Center;var title=Text(completed!.Text,27);title.TextAlignment=TextAlignment.Center;title.Margin=new Thickness(24);center.Children.Add(title);center.Children.Add(Mascot(true,64,64));area.Children.Add(center);body.Children.Add(area);
        var next=Button(T("Next thing","下一件"),()=>{completed=null;route="write";draft="";Render();editor?.Focus();},true);next.Margin=new Thickness(24,0,24,0);body.Children.Add(next);
        body.Children.Add(Button(T("Back home","返回首页"),()=>{completed=null;route="home";Render();}));if(SystemParameters.ClientAreaAnimation)fireworks.Start();
    }
    void History(StackPanel body){
        Height=390;var items=Stack();items.Margin=new Thickness(24);items.Children.Add(Text(T("History","历史记录"),23));
        if(document.State.History.Count==0)items.Children.Add(Text(T("Your finished things will be here.","做过的事会留在这里。"),13,Muted));
        foreach(var h in document.State.History.OrderByDescending(h=>h.Date)){var row=new DockPanel{Margin=new Thickness(0,16,0,12)};if(!h.Completed){var mark=Text("Ⅱ",11,Muted);mark.ToolTip=T("Replaced unfinished","未完成，已换下");DockPanel.SetDock(mark,Dock.Right);row.Children.Add(mark);}var col=Stack();col.Children.Add(Text(h.Text,15));var date=Text(Clock.From(h.Date).ToString("d",Zh?CultureInfo.GetCultureInfo("zh-CN"):CultureInfo.GetCultureInfo("en-US")),11,Muted);date.Margin=new Thickness(0,6,0,0);col.Children.Add(date);row.Children.Add(col);items.Children.Add(row);items.Children.Add(new Border{Height=1,Background=Mint});}body.Children.Add(new ScrollViewer{Height=350,Content=items,VerticalScrollBarVisibility=ScrollBarVisibility.Auto});
    }
    void Settings(StackPanel body){
        Height=450;var box=Stack();box.Margin=new Thickness(24);box.Children.Add(Text(T("Preferences","偏好设置"),23));
        var language=new ComboBox{ItemsSource=new[]{"English","简体中文"},SelectedIndex=Zh?1:0,Margin=new Thickness(0,18,0,12)};language.SelectionChanged+=(s,e)=>{var n=Disk.Copy(document);n.State.Language=language.SelectedIndex==1?"zh":"en";n.State.GeneratedTips.Clear();if(Persist(n))Render();};box.Children.Add(language);
        var companion=new CheckBox{Content=T("Companion messages","小家伙的话"),IsChecked=document.State.CompanionEnabled,Margin=new Thickness(0,8,0,12)};companion.Click+=(s,e)=>{var n=Disk.Copy(document);n.State.CompanionEnabled=companion.IsChecked==true;Persist(n);};box.Children.Add(companion);
        using var key=Registry.CurrentUser.OpenSubKey("Software\\Microsoft\\Windows\\CurrentVersion\\Run");var startup=new CheckBox{Content=T("Open at login","登录后启动"),IsChecked=key?.GetValue("Miaotou")!=null,Margin=new Thickness(0,4,0,16)};
        startup.Click+=(s,e)=>{try{using var k=Registry.CurrentUser.CreateSubKey("Software\\Microsoft\\Windows\\CurrentVersion\\Run");if(startup.IsChecked==true)k.SetValue("Miaotou","\""+Environment.ProcessPath+"\"");else k.DeleteValue("Miaotou",false);}catch{System.Windows.MessageBox.Show(T("Could not change login settings.","暂时无法修改登录设置。"),"小苗头");}};box.Children.Add(startup);
        box.Children.Add(Text(T("Saved on this PC. Offline editorial ideas. Automatic sync isn't available yet.","记录保存在这台电脑，使用离线精选内容。暂未开启跨设备自动同步。"),11,Muted));
        var actions=new StackPanel{Orientation=Orientation.Horizontal};actions.Children.Add(Button(T("Export record","导出记录"),Export));actions.Children.Add(Button(T("Import record","导入记录"),Import));box.Children.Add(actions);body.Children.Add(box);
    }
    void Export(){var d=new SaveFileDialog{FileName="miaotou.json",Filter="JSON|*.json"};if(d.ShowDialog()==true)try{File.WriteAllText(d.FileName,System.Text.Json.JsonSerializer.Serialize(document.State,Disk.Json));}catch{System.Windows.MessageBox.Show(T("Could not export.","暂时无法导出。"));}}
    void Import(){var d=new OpenFileDialog{Filter="JSON|*.json"};if(d.ShowDialog()!=true)return;try{if(new FileInfo(d.FileName).Length>10_000_000)throw new InvalidDataException();var incoming=System.Text.Json.JsonSerializer.Deserialize<ThingState>(File.ReadAllText(d.FileName),Disk.Json);if(incoming==null||incoming.Schema!=1||incoming.History==null||incoming.GeneratedTips==null)throw new InvalidDataException();if(System.Windows.MessageBox.Show(T("Replace this PC's record? A backup will be saved first.","替换这台电脑的记录？替换前会先保存备份。"),"小苗头",MessageBoxButton.OKCancel)!=MessageBoxResult.OK)return;if(File.Exists(disk.FilePath))File.Copy(disk.FilePath,disk.FilePath+".backup-"+Guid.NewGuid()+".json");var n=Disk.Copy(document);n.State=incoming;if(Persist(n)){completed=null;route="home";Render();}}catch{System.Windows.MessageBox.Show(T("This file could not be imported. Your record is safe.","无法导入这份文件，当前记录还在。"));}}
    void About(StackPanel body){Height=300;var box=Stack();box.Margin=new Thickness(24);box.Children.Add(Mascot(false,70,48));var title=Text("小苗头",24);title.TextAlignment=TextAlignment.Center;title.Margin=new Thickness(0,16,0,8);box.Children.Add(title);var version=Text("1.0 (1) · Windows",11,Muted);version.TextAlignment=TextAlignment.Center;box.Children.Add(version);var description=Text(T("Keep one thing you want to do in sight.\n\nYour record stays on this PC. No account, analytics or cloud upload. This version is free.","让自己想做的那件事，每天看得见。\n\n记录保存在这台电脑。无需账号，没有分析追踪或云端上传。此版本免费。"),13);description.TextAlignment=TextAlignment.Center;description.Margin=new Thickness(0,18,0,0);box.Children.Add(description);body.Children.Add(box);}
}
