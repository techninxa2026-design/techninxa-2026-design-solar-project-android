import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'api.dart';
import 'copy.dart';
import 'theme.dart';
import 'tide_cards.dart';

/// A restrained solar-specific visual vocabulary. No simulated business metrics.
class TideContour extends CustomPainter {
  final Color color;
  const TideContour(this.color);
  @override void paint(Canvas canvas,Size size){
    final p=Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=1;
    for(var i=0;i<6;i++){
      final offset=i*13.0;
      canvas.drawPath(Path()..moveTo(size.width*.35+offset,-8)
        ..cubicTo(size.width*.95+offset,size.height*.04,size.width*.52+offset,size.height*.8,size.width+offset,size.height*.84),p);
    }
  }
  @override bool shouldRepaint(TideContour oldDelegate)=>oldDelegate.color!=color;
}
class TideBanner extends StatelessWidget {
  final String eyebrow,title,subtitle;
  final IconData icon;
  final Brand? brand;
  final Widget? trailing;
  const TideBanner({super.key,required this.eyebrow,required this.title,required this.subtitle,required this.icon,this.brand,this.trailing});
  @override Widget build(BuildContext c){
    final s=Theme.of(c).colorScheme;
    final a=brand?.deep??contrast(s.primary);
    final b=contrast(brand?.primary??const Color(0xff087eb1));
    return ClipRRect(borderRadius:BorderRadius.circular(28),child:DecoratedBox(
      decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[a,b])),
      child:Stack(children:[
        Positioned.fill(child:CustomPaint(painter:TideContour(Colors.white.withValues(alpha:.17)))),
        Positioned(right:-15,bottom:-24,child:Icon(icon,size:126,color:Colors.white.withValues(alpha:.09))),
        Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.17),borderRadius:BorderRadius.circular(16)),child:Icon(icon,color:Colors.white,size:23)),
            const SizedBox(width:12),Expanded(child:CopyText(eyebrow,style:const TextStyle(color:Colors.white,fontSize:11,letterSpacing:1.2,fontWeight:FontWeight.w800))),
            if(trailing!=null)trailing!]),
          const SizedBox(height:18),
          CopyText(title,style:const TextStyle(color:Colors.white,fontSize:26,fontWeight:FontWeight.w800,height:1.15,letterSpacing:-.5)),
          const SizedBox(height:8),
          CopyText(subtitle,style:const TextStyle(color:Colors.white,fontSize:13,height:1.4)),
        ])),
      ]),
    ));
  }
}
class TideAvatar extends StatelessWidget {
  final String name;
  final double size;
  const TideAvatar(this.name,{super.key,this.size=52});
  @override Widget build(BuildContext c){
    final s=Theme.of(c).colorScheme;
    final letters=name.trim().split(RegExp(r'\s+')).where((s)=>s.isNotEmpty).take(2).map((s)=>s.characters.first.toUpperCase()).join();
    return Container(width:size,height:size,alignment:Alignment.center,decoration:BoxDecoration(
      shape:BoxShape.circle,gradient:LinearGradient(colors:[tideTint(c,s.primary,.23),tideTint(c,s.primary,.07)])),
      child:Text(letters.isEmpty?'?':letters,style:TextStyle(color:s.primary,fontSize:size*.34,fontWeight:FontWeight.w800)));
  }
}
class TideSetting extends StatelessWidget {
  final IconData icon;final String title;final String? subtitle;final Widget? trailing;final VoidCallback? onTap;final bool danger;
  const TideSetting({super.key,required this.icon,required this.title,this.subtitle,this.trailing,this.onTap,this.danger=false});
  @override Widget build(BuildContext c){
    final s=Theme.of(c).colorScheme;
    return Material(color:Colors.transparent,child:InkWell(borderRadius:BorderRadius.circular(18),onTap:onTap,child:Padding(
      padding:const EdgeInsets.symmetric(vertical:10,horizontal:5),child:Row(children:[
      Container(width:44,height:44,decoration:BoxDecoration(color:tideTint(c,danger?s.error:s.primary,.10),borderRadius:BorderRadius.circular(15)),child:Icon(icon,color:danger?s.error:s.primary,size:21)),
      const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        CopyText(title,style:Theme.of(c).textTheme.titleSmall?.copyWith(color:danger?s.error:null)),
        if(subtitle!=null)CopyText(subtitle!,style:Theme.of(c).textTheme.bodySmall),
      ])),if(trailing!=null)trailing! else if(onTap!=null)Icon(Icons.chevron_right_rounded,color:s.onSurfaceVariant),
    ]))));
  }
}
class TideNotice extends StatelessWidget {
  final String message;final String? title;final bool error;final VoidCallback? retry;
  const TideNotice(this.message,{super.key,this.title,this.error=false,this.retry});
  @override Widget build(BuildContext c){
    final s=Theme.of(c).colorScheme;final ink=error?s.error:s.primary;
    return Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:tideTint(c,ink,.08),
      borderRadius:BorderRadius.circular(20),border:Border.all(color:ink.withValues(alpha:.22))),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(error?Icons.error_outline_rounded:Icons.info_outline_rounded,color:ink,size:24),
        const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(title!=null)...[CopyText(title!,style:Theme.of(c).textTheme.titleSmall?.copyWith(color:ink)),const SizedBox(height:5)],
          CopyText(message,style:Theme.of(c).textTheme.bodyMedium),
          if(retry!=null)TextButton(onPressed:retry,child:const CopyText('Retry')),
        ]))
      ]));
  }
}
class TideLoading extends StatelessWidget {
  const TideLoading({super.key});
  @override Widget build(BuildContext c)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const TideGlyph(Icons.sync_rounded,size:62),const SizedBox(height:16),
    const LinearProgressIndicator(borderRadius:BorderRadius.all(Radius.circular(10))),
    const SizedBox(height:12),CopyText('Loading…',style:Theme.of(c).textTheme.titleSmall),
  ])));
}
class TideFieldGroup extends StatelessWidget {
  final String label;final String value;final IconData icon;
  const TideFieldGroup({super.key,required this.label,required this.value,required this.icon});
  @override Widget build(BuildContext c)=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(icon,size:19,color:Theme.of(c).colorScheme.primary),const SizedBox(width:10),
    Expanded(child:TideFact(label:label,value:value)),
  ]);
}
class TideProductPhoto extends StatefulWidget {
  final Api api;final int id;
  const TideProductPhoto({super.key,required this.api,required this.id});
  @override State<TideProductPhoto> createState()=>_TideProductPhotoState();
}
class _TideProductPhotoState extends State<TideProductPhoto>{
  late Future<Uint8List> image=widget.api.bytes('/inventory/products/'+widget.id.toString()+'/image');
  @override void didUpdateWidget(covariant TideProductPhoto old){super.didUpdateWidget(old);if(old.api!=widget.api||old.id!=widget.id)image=widget.api.bytes('/inventory/products/'+widget.id.toString()+'/image');}
  @override Widget build(BuildContext c)=>ClipRRect(borderRadius:BorderRadius.circular(17),child:Container(
    width:78,height:78,color:Colors.white,child:FutureBuilder<Uint8List>(future:image,builder:(c,s){
      final bytes=s.data;return bytes==null||bytes.isEmpty?const TideGlyph(Icons.inventory_2_outlined,size:78):
        Image.memory(bytes,fit:BoxFit.contain,errorBuilder:(_,__,___)=>const TideGlyph(Icons.inventory_2_outlined,size:78));
    })));
}
class TideTimelineEntry extends StatelessWidget {
  final String title;final String? description,stamp;final bool last;final Widget? actions;
  const TideTimelineEntry({super.key,required this.title,this.description,this.stamp,this.last=false,this.actions});
  @override Widget build(BuildContext c){
    final s=Theme.of(c).colorScheme;
    return IntrinsicHeight(child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      SizedBox(width:24,child:Column(children:[
        Container(width:13,height:13,decoration:BoxDecoration(color:s.primary,shape:BoxShape.circle,border:Border.all(color:tideTint(c,s.primary,.2),width:3))),
        if(!last)Expanded(child:Container(width:2,color:s.outline.withValues(alpha:.6))),
      ])),const SizedBox(width:8),
      Expanded(child:Padding(padding:const EdgeInsets.only(bottom:14),child:TideSurface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(stamp!=null)...[CopyText(stamp!,style:Theme.of(c).textTheme.labelMedium),const SizedBox(height:5)],
        CopyText(title,style:Theme.of(c).textTheme.titleMedium),
        if(description!=null&&description!=title)...[const SizedBox(height:7),CopyText(description!)],
        if(actions!=null)actions!,
      ])))),
    ]));
  }
}
