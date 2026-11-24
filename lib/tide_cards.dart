import 'package:flutter/material.dart';
import 'copy.dart';

/// Tide Flow / Prism: expressive native cards, not data or permission logic.
/// All displayed values are passed by the existing authorized views.
Color tideTint(BuildContext context, Color color, double amount) =>
    Color.alphaBlend(color.withValues(alpha: amount), Theme.of(context).colorScheme.surface);

class TideGlyph extends StatelessWidget {
  final IconData icon;
  final double size;
  const TideGlyph(this.icon,{super.key,this.size=48});
  @override
  Widget build(BuildContext context) {
    final s=Theme.of(context).colorScheme;
    return Container(
      width:size,height:size,
      decoration:BoxDecoration(
        gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
          colors:[tideTint(context,s.primary,.17),tideTint(context,s.primary,.07)]),
        border:Border.all(color:s.primary.withValues(alpha:.18)),
        borderRadius:BorderRadius.circular(size*.33)),
      child:Icon(icon,size:size*.48,color:s.primary),
    );
  }
}

class TideSurface extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool tinted;
  const TideSurface({super.key,required this.child,this.onTap,
    this.padding=const EdgeInsets.all(16),this.tinted=false});
  @override
  Widget build(BuildContext context) {
    final s=Theme.of(context).colorScheme;
    final radius=BorderRadius.circular(24);
    return Card(
      margin:EdgeInsets.zero,clipBehavior:Clip.antiAlias,
      color:s.surface,surfaceTintColor:Colors.transparent,
      elevation:Theme.of(context).brightness==Brightness.dark?0:2,
      shadowColor:s.primary.withValues(alpha:.18),
      shape:RoundedRectangleBorder(borderRadius:radius,
        side:BorderSide(color:s.outline.withValues(alpha:.64))),
      child:Ink(
        decoration:BoxDecoration(gradient:LinearGradient(
          begin:Alignment.topLeft,end:Alignment.bottomRight,
          colors:[tinted?tideTint(context,s.primary,.10):s.surface,
            tideTint(context,s.primary,.025)])),
        child:InkWell(onTap:onTap,borderRadius:radius,
          child:Padding(padding:padding,child:child)),
      ),
    );
  }
}

class TideSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const TideSection({super.key,required this.title,this.subtitle,this.trailing});
  @override
  Widget build(BuildContext context) {
    final t=Theme.of(context);
    return Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
      Container(width:4,height:32,decoration:BoxDecoration(
        color:t.colorScheme.primary,borderRadius:BorderRadius.circular(6))),
      const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        CopyText(title,style:t.textTheme.titleLarge),
        if(subtitle!=null) ...[const SizedBox(height:3),
          CopyText(subtitle!,style:t.textTheme.bodySmall)],
      ])),
      if(trailing!=null)...[const SizedBox(width:8),trailing!],
    ]);
  }
}

class TideGrid extends StatelessWidget {
  final List<Widget> children;
  final int maxColumns;
  const TideGrid({super.key,required this.children,this.maxColumns=3});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder:(context,bounds){
    final scale=MediaQuery.textScalerOf(context).scale(16)/16;
    final width=bounds.maxWidth;
    final columns=width<335||scale>1.35?1:width>=720&&maxColumns>=3?3:2;
    const gap=12.0;
    final cell=(width-(columns-1)*gap)/columns;
    return Wrap(spacing:gap,runSpacing:gap,
      children:children.map((child)=>SizedBox(width:cell,child:child)).toList());
  });
}

class TideMetric extends StatelessWidget {
  final String label,value;
  final IconData icon;
  final String? supporting;
  final VoidCallback? onTap;
  const TideMetric({super.key,required this.label,required this.value,
    required this.icon,this.supporting,this.onTap});
  @override
  Widget build(BuildContext context) {
    final t=Theme.of(context);
    return TideSurface(tinted:true,onTap:onTap,child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          TideGlyph(icon,size:42),
          const Spacer(),
          if(onTap!=null)Icon(Icons.arrow_outward,size:19,color:t.colorScheme.primary),
        ]),
        const SizedBox(height:15),
        CopyText(value,style:t.textTheme.headlineLarge?.copyWith(
          color:t.colorScheme.primary,fontWeight:FontWeight.w900,letterSpacing:-1)),
        const SizedBox(height:5),
        CopyText(label,style:t.textTheme.titleSmall),
        if(supporting!=null)...[const SizedBox(height:8),
          CopyText(supporting!,style:t.textTheme.bodySmall)],
      ]));
  }
}

class TideModuleTile extends StatelessWidget {
  final String title,subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;
  const TideModuleTile({super.key,required this.title,required this.subtitle,
    required this.icon,required this.onTap,this.compact=false});
  @override
  Widget build(BuildContext context) {
    final t=Theme.of(context);
    final content=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      CopyText(title,style:t.textTheme.titleMedium),
      const SizedBox(height:4),
      CopyText(subtitle,style:t.textTheme.bodySmall),
    ]);
    return TideSurface(onTap:onTap,child:compact?Row(children:[
      TideGlyph(icon,size:46),const SizedBox(width:13),Expanded(child:content),
      const SizedBox(width:8),Icon(Icons.arrow_forward_ios_rounded,size:14,color:t.colorScheme.primary),
    ]):Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[TideGlyph(icon),const Spacer(),
        Icon(Icons.arrow_outward,size:18,color:t.colorScheme.primary)]),
      const SizedBox(height:15),content,
    ]));
  }
}

class TideStatus extends StatelessWidget {
  final String value;
  const TideStatus(this.value,{super.key});
  @override
  Widget build(BuildContext context) {
    final scheme=Theme.of(context).colorScheme;
    final dark=Theme.of(context).brightness==Brightness.dark;
    final normalized=value.toLowerCase().replaceAll(RegExp(r'[\s_-]'),'');
    final good=['active','approved','accepted','completed','verified','sent','read'].contains(normalized);
    final bad=['rejected','failed','disabled','inactive','revoked','cancelled','canceled'].contains(normalized);
    final waiting=['pending','inprogress','unread','offered','assigned','sending'].contains(normalized);
    final ink=good?(dark?const Color(0xff9CE6C8):const Color(0xff146448)):
      bad?(dark?const Color(0xffFFB4AB):const Color(0xffA22B35)):
      waiting?(dark?const Color(0xffFFD99A):const Color(0xff81530B)):scheme.primary;
    return Container(
      padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),
      decoration:BoxDecoration(color:tideTint(context,ink,.10),
        border:Border.all(color:ink.withValues(alpha:.25)),
        borderRadius:BorderRadius.circular(20)),
      child:Row(mainAxisSize:MainAxisSize.min,children:[
        Icon(good?Icons.check_circle_outline:bad?Icons.error_outline:
          waiting?Icons.schedule:Icons.info_outline,size:15,color:ink),
        const SizedBox(width:5),
        Flexible(child:CopyText(value,style:TextStyle(color:ink,fontWeight:FontWeight.w700,fontSize:12))),
      ]),
    );
  }
}

class TideFact extends StatelessWidget {
  final String label,value;
  final bool emphasis;
  const TideFact({super.key,required this.label,required this.value,this.emphasis=false});
  @override
  Widget build(BuildContext context) {
    final t=Theme.of(context);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      CopyText(label,style:t.textTheme.labelMedium?.copyWith(color:t.colorScheme.onSurfaceVariant)),
      const SizedBox(height:4),
      CopyText(value,style:emphasis?t.textTheme.titleLarge?.copyWith(color:t.colorScheme.primary):
        t.textTheme.bodyMedium?.copyWith(fontWeight:FontWeight.w600)),
    ]);
  }
}

class TideEmpty extends StatelessWidget {
  final String message;
  const TideEmpty({super.key,this.message='No records available in this view.'});
  @override
  Widget build(BuildContext context)=>TideSurface(tinted:true,child:Row(children:[
    const TideGlyph(Icons.inbox_outlined),const SizedBox(width:12),
    Expanded(child:CopyText(message,style:Theme.of(context).textTheme.bodyMedium)),
  ]));
}
