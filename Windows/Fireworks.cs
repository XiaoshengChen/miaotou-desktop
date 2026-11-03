using System;
using System.Diagnostics;
using System.Windows;
using System.Windows.Media;

namespace Miaotou;
public sealed class Fireworks:FrameworkElement {
    readonly Stopwatch clock=new();bool running;
    readonly Color[] colors={Color.FromRgb(36,128,115),Color.FromRgb(179,130,46),Color.FromRgb(71,158,156),Color.FromRgb(199,112,87)};
    public void Start(){clock.Restart();running=true;CompositionTarget.Rendering+=Frame;Unloaded+=(s,e)=>Stop();}
    public void Stop(){if(running){running=false;CompositionTarget.Rendering-=Frame;}}
    void Frame(object? sender,EventArgs e){InvalidateVisual();if(clock.Elapsed.TotalSeconds>4.3)Stop();}
    protected override void OnRender(DrawingContext dc){
        double time=clock.Elapsed.TotalSeconds;if(time>4.3)return;
        (double x,double y,double delay)[] bursts={(.2,-50,.08),(.82,-45,.27),(.08,8,.63),(.90,30,.8),(.48,-80,1.06),(.17,-40,1.39),(.77,-60,1.59),(.5,80,1.78)};
        for(int n=0;n<bursts.Length;n++){
            var b=bursts[n];double age=time-b.delay;if(age<0)continue;double x=ActualWidth*b.x,y=Math.Clamp(ActualHeight*.44+b.y,15,Math.Max(15,ActualHeight-15));double ascent=.48+n%3*.05;
            if(age<ascent){double p=age/ascent,origin=ActualWidth*(n%2==0?.12:.88);Point At(double a){double e=1-Math.Pow(1-Math.Max(0,a),2);return new(origin+(x-origin)*e,ActualHeight+(y-ActualHeight)*e);}dc.DrawLine(new Pen(new SolidColorBrush(colors[n%4]),1.8),At(p),At(p-.05));}
            else for(int spark=0;spark<48;spark++){
                double e=age-ascent,v=(spark*37+n*19)%100/100.0,life=1+v*.65;if(e>life)continue;double angle=spark*Math.PI*2/48,speed=(spark%3==0?100:70)*(.72+v*.5);
                Point At(double a){a=Math.Max(0,a);double travel=(1-Math.Exp(-a*1.65))/1.65;return new(x+Math.Cos(angle)*speed*travel,y+Math.Sin(angle)*speed*travel+20*a*a);}
                var color=colors[n%4];color.A=(byte)(255*Math.Pow(1-e/life,.7));dc.DrawLine(new Pen(new SolidColorBrush(color),spark%3==0?1.8:1.2),At(e),At(e-.09));
            }
        }
    }
}
