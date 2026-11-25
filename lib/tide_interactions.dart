import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'copy.dart';
import 'feedback.dart';
import 'theme.dart';
import 'tide_cards.dart';
import 'tide_editorial.dart';

Future<T?> showTideSheet<T>(BuildContext context,{required String title,required String subtitle,required IconData icon,required WidgetBuilder content}) =>
 showModalBottomSheet<T>(context:context,isScrollControlled:true,useSafeArea:true,backgroundColor:Colors.transparent,
 builder:(c)=>Padding(padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(c).bottom),child:LayoutBuilder(builder:(c,box){
 final s=Theme.of(c).colorScheme;
 return Material(color:s.surface,clipBehavior:Clip.antiAlias,borderRadius:const BorderRadius.vertical(top:Radius.circular(32)),
 child:SafeArea(top:false,child:ConstrainedBox(constraints:BoxConstraints(maxHeight:box.maxHeight*.94),
 child:Column(mainAxisSize:MainAxisSize.min,children:[
 const SizedBox(height:9),Container(width:40,height:4,decoration:BoxDecoration(color:s.outline,borderRadius:BorderRadius.circular(4))),
 Flexible(child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(16,12,16,20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 ClipRRect(borderRadius:BorderRadius.circular(24),child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(colors:[contrast(s.primary),contrast(Color.lerp(s.primary,s.secondary,.55)!)])),
 child:Stack(children:[
 Positioned.fill(child:CustomPaint(painter:TideContour(Colors.white.withValues(alpha:.17)))),
 Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Row(children:[Icon(icon,color:Colors.white,size:25),const Spacer(),IconButton(tooltip:'Close',onPressed:()=>Navigator.pop(c),icon:const Icon(Icons.close_rounded,color:Colors.white))]),
 CopyText(title,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w800,height:1.2)),
 const SizedBox(height:6),CopyText(subtitle,style:const TextStyle(color:Colors.white,fontSize:13,height:1.4)),
 ])),
 ]))),
 const SizedBox(height:16),Builder(builder:content),
 ]))),
 ]))));
 })));

class TideChoiceList extends StatefulWidget{
 final Map<String,String> values;final Set<String> selected;final bool multiple;
 const TideChoiceList({super.key,required this.values,required this.selected,this.multiple=false});
 @override State<TideChoiceList> createState()=>_TideChoiceListState();
}
class _TideChoiceListState extends State<TideChoiceList>{
 String query='';late final Set<String> selected={...widget.selected};
 @override Widget build(BuildContext c){
 final s=Theme.of(c).colorScheme;final q=query.trim().toLowerCase();
 final matches=widget.values.entries.where((e)=>tr(c,e.value).toLowerCase().contains(q)||e.value.toLowerCase().contains(q)).toList();
 return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 if(widget.values.length>5)...[TextField(decoration:const InputDecoration(hintText:'Search options',prefixIcon:Icon(Icons.search_rounded)),onChanged:(v)=>setState(()=>query=v)),const SizedBox(height:12)],
 if(widget.multiple)...[Wrap(spacing:12,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[CopyText(selected.length.toString()+' selected',style:Theme.of(c).textTheme.titleSmall),FilledButton.icon(onPressed:()=>Navigator.pop(c,selected),icon:const Icon(Icons.check_rounded),label:const CopyText('Apply selection'))]),const SizedBox(height:8)],
 if(matches.isEmpty)const TideEmpty(message:'No matching options.'),
 for(final entry in matches)Padding(padding:const EdgeInsets.only(bottom:7),child:TideSurface(tinted:selected.contains(entry.key),padding:const EdgeInsets.symmetric(horizontal:13,vertical:11),
 onTap:(){if(!widget.multiple){Navigator.pop(c,entry.key);return;}setState(()=>selected.contains(entry.key)?selected.remove(entry.key):selected.add(entry.key));},
 child:Row(children:[Icon(selected.contains(entry.key)?Icons.check_circle_rounded:widget.multiple?Icons.check_box_outline_blank_rounded:Icons.radio_button_unchecked,color:s.primary,size:22),const SizedBox(width:12),Expanded(child:CopyText(entry.value,style:Theme.of(c).textTheme.bodyLarge))]))),
 if(widget.multiple&&matches.length>6)...[const SizedBox(height:8),FilledButton.icon(onPressed:()=>Navigator.pop(c,selected),icon:const Icon(Icons.check_rounded),label:const CopyText('Apply selection'))],
 ]);
 }
}
class TideSelectField extends StatelessWidget{
 final String label,value;final Map<String,String> options;final bool required,enabled;final ValueChanged<String> onChanged;
 const TideSelectField({super.key,required this.label,required this.value,required this.options,required this.required,required this.enabled,required this.onChanged});
 @override Widget build(BuildContext c)=>FormField<String>(key:ValueKey(value),initialValue:value,autovalidateMode:AutovalidateMode.onUserInteraction,
 validator:(v)=>required&&(v==null||v.isEmpty)?'Select '+label+'.':null,builder:(state)=>InkWell(borderRadius:BorderRadius.circular(17),onTap:!enabled?null:()async{
 final result=await showTideSheet<String>(c,title:label,subtitle:'Choose one option',icon:Icons.checklist_rounded,content:(_)=>TideChoiceList(values:{if(!required)'':'None',...options},selected:{value}));
 if(result!=null&&state.mounted&&c.mounted){state.didChange(result);onChanged(result);}
 },child:InputDecorator(decoration:InputDecoration(labelText:tr(c,label)+(required?' *':''),errorText:state.errorText,enabled:enabled),isEmpty:false,
 child:Row(children:[Expanded(child:CopyText(value.isEmpty?'Choose a value':options[value]??value,style:Theme.of(c).textTheme.bodyLarge)),const SizedBox(width:8),const Icon(Icons.expand_more_rounded)]))));
}
String tideColorHex(Color color)=>'#'+(color.toARGB32()&0xffffff).toRadixString(16).padLeft(6,'0').toUpperCase();
Color? tideParseColor(String value)=>RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)?Color(int.parse('ff'+value.substring(1),radix:16)):null;
class TideColorField extends StatelessWidget{
 final String label,value;final bool required,enabled;final ValueChanged<String> onChanged;
 const TideColorField({super.key,required this.label,required this.value,required this.required,required this.enabled,required this.onChanged});
 @override Widget build(BuildContext c)=>FormField<String>(key:ValueKey(value),initialValue:value,autovalidateMode:AutovalidateMode.onUserInteraction,
 validator:(v)=>((v??'').isEmpty&&!required)||tideParseColor(v??'')!=null?null:'Select a valid '+label+'.',
 builder:(state){final color=tideParseColor(value);
 return InkWell(borderRadius:BorderRadius.circular(17),onTap:!enabled?null:()async{
 final picked=await showTideSheet<Color>(c,title:label,subtitle:'Choose a palette color or create your own shade.',icon:Icons.palette_outlined,content:(_)=>TideColorPicker(initial:color??ocean));
 if(picked!=null&&state.mounted&&c.mounted){final next=tideColorHex(picked);state.didChange(next);onChanged(next);}
 },child:InputDecorator(decoration:InputDecoration(labelText:tr(c,label)+(required?' *':''),enabled:enabled,errorText:state.errorText),
 child:Row(children:[
 Container(width:42,height:42,decoration:BoxDecoration(color:color??Theme.of(c).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(12),border:Border.all(color:Theme.of(c).colorScheme.outline))),
 const SizedBox(width:12),Expanded(child:CopyText(color==null?'Choose a color':'Selected color',style:Theme.of(c).textTheme.bodyLarge)),const Icon(Icons.palette_outlined),
 ])));});
}
class TideColorPicker extends StatefulWidget{
 final Color initial;const TideColorPicker({super.key,required this.initial});
 @override State<TideColorPicker> createState()=>_TideColorPickerState();
}
class _TideColorPickerState extends State<TideColorPicker>{
 late HSVColor hsv=HSVColor.fromColor(widget.initial);
 @override Widget build(BuildContext c){
 final color=hsv.toColor();final foreground=color.computeLuminance()>.179?Colors.black:Colors.white;
 const colors=[Color(0xff087eb1),Color(0xff16a9cf),Color(0xff2358ba),Color(0xff5845bf),Color(0xff008575),Color(0xff18734b),Color(0xffba641f),Color(0xffbd3954),Color(0xff34495e),Color(0xff202a36)];
 Widget control(String name,double value,double max,ValueChanged<double> change)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 CopyText(name,style:Theme.of(c).textTheme.titleSmall),Slider(value:value,max:max,onChanged:change,activeColor:contrast(color))]);
 return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 Container(padding:const EdgeInsets.all(19),decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(22)),child:Row(children:[
 Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CopyText('Brand preview',style:TextStyle(color:foreground,fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:5),Text(tideColorHex(color),style:TextStyle(color:foreground,fontSize:12))])),Icon(Icons.check_circle_outline,color:foreground,size:28)])),
 const SizedBox(height:16),const TideSection(title:'Curated palette'),const SizedBox(height:10),
 Wrap(spacing:10,runSpacing:10,children:colors.map((x)=>Semantics(button:true,selected:x.toARGB32()==color.toARGB32(),label:'Color '+tideColorHex(x),child:InkWell(borderRadius:BorderRadius.circular(15),onTap:()=>setState(()=>hsv=HSVColor.fromColor(x)),child:Container(width:48,height:48,decoration:BoxDecoration(color:x,borderRadius:BorderRadius.circular(15)),child:x.toARGB32()==color.toARGB32()?const Icon(Icons.check,color:Colors.white):null)))).toList()),
 const SizedBox(height:20),const TideSection(title:'Custom shade'),const SizedBox(height:12),
 Container(height:18,decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),gradient:const LinearGradient(colors:[Colors.red,Colors.yellow,Colors.green,Colors.cyan,Colors.blue,Colors.purple,Colors.red]))),
 control('Hue',hsv.hue,360,(v)=>setState(()=>hsv=hsv.withHue(v))),
 control('Saturation',hsv.saturation,1,(v)=>setState(()=>hsv=hsv.withSaturation(v))),
 control('Brightness',hsv.value,1,(v)=>setState(()=>hsv=hsv.withValue(v))),
 FilledButton.icon(onPressed:()=>Navigator.pop(c,color),icon:const Icon(Icons.check_rounded),label:const CopyText('Use this color')),
 ]);
 }
}

Uri? tideMapUri({String? gps,String? address}){
 final u=Uri.tryParse(gps?.trim()??'');
 if(u!=null&&u.scheme=='https'&&u.userInfo.isEmpty&&(!u.hasPort||u.port==443)){
 final h=u.host.toLowerCase();
 if(h=='maps.app.goo.gl'||h=='maps.google.com'||((h=='www.google.com'||h=='google.com'||h=='www.google.com.bd')&&(u.path=='/maps'||u.path.startsWith('/maps/')))||(h=='goo.gl'&&u.path.startsWith('/maps/'))||h=='www.openstreetmap.org'||h=='openstreetmap.org')return u;
 }
 final query=address?.trim()??'';if(query.isEmpty)return null;
 return Uri.https('www.google.com','/maps/search/',{'api':'1','query':query});
}
bool tideAddressKey(String key)=>['address','customeraddress','warehouseaddress','companyaddress','clientaddress','installationaddress','locationaddress'].contains(key.toLowerCase());
class TideMapLink extends StatelessWidget{
 final String? address,gps;final bool compact;
 const TideMapLink({super.key,this.address,this.gps,this.compact=false});
 @override Widget build(BuildContext c){
 final uri=tideMapUri(gps:gps,address:address);if(uri==null)return CopyText(address??gps??'');
 final s=Theme.of(c).colorScheme;final hasPin=tideMapUri(gps:gps)!=null;
 return Material(color:tideTint(c,s.primary,.08),borderRadius:BorderRadius.circular(16),child:InkWell(borderRadius:BorderRadius.circular(16),onTap:()async{
 try{if(await launchUrl(uri,mode:LaunchMode.externalApplication))return;}catch(_){}
 if(c.mounted)showFeedback('Unable to open Maps.',context:c,kind:FeedbackKind.error);
 },child:Padding(padding:const EdgeInsets.all(12),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Icon(Icons.location_on_outlined,color:s.primary,size:22),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 if((address??'').trim().isNotEmpty)CopyText(address!,style:Theme.of(c).textTheme.bodyMedium),
 if(!compact||(address??'').trim().isEmpty)...[const SizedBox(height:3),CopyText(hasPin?'Open saved location':'Search in Maps',style:Theme.of(c).textTheme.titleSmall?.copyWith(color:s.primary))],
 ])),Icon(Icons.arrow_outward_rounded,size:18,color:s.primary),
 ]))));
 }
}
class TideSegments<T> extends StatelessWidget{
 final List<ButtonSegment<T>> segments;final Set<T> selected;final ValueChanged<Set<T>> onSelectionChanged;
 const TideSegments({super.key,required this.segments,required this.selected,required this.onSelectionChanged});
 @override Widget build(BuildContext c)=>Wrap(spacing:8,runSpacing:6,children:segments.map((item)=>ChoiceChip(label:item.label??Text(item.value.toString()),selected:selected.contains(item.value),showCheckmark:false,avatar:selected.contains(item.value)?const Icon(Icons.check_rounded,size:17):item.icon,onSelected:item.enabled?(_)=>onSelectionChanged({item.value}):null,padding:const EdgeInsets.symmetric(horizontal:10,vertical:9))).toList());
}
