import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'api.dart';
import 'copy.dart';
import 'theme.dart';
import 'tide_cards.dart';
import 'tide_interactions.dart';

/// Load only known IDCOLDA logo paths using the existing authorized transport.
/// No arbitrary external URLs, no bearer token in an image URL, no disk cache.
class CompanyLogo extends StatefulWidget {
  final Api api;
  final Brand brand;
  final Object? companyId;
  final double size;
  const CompanyLogo({super.key,required this.api,required this.brand,
    this.companyId,this.size=64});
  @override State<CompanyLogo> createState()=>_CompanyLogoState();
}
class _CompanyLogoState extends State<CompanyLogo>{
  Future<Uint8List?>? future;
  String? get logo=>widget.brand.logo;
  @override void initState(){super.initState();load();}
  @override void didUpdateWidget(covariant CompanyLogo old){
    super.didUpdateWidget(old);
    if(old.api!=widget.api||old.brand.logo!=logo||old.companyId!=widget.companyId||old.brand.slug!=widget.brand.slug)load();
  }
  void load(){
    future=null;
    final p=logo;
    if(p==null)return;
    final match=RegExp(r'^/api/v1/companies/([1-9][0-9]*)/logo$').firstMatch(p);
    if(match!=null&&match.group(1)==widget.companyId?.toString()){
      future=fetch(p.substring('/api/v1'.length),true);
    }else if(RegExp(r'^/company/[A-Za-z0-9-]+/logo$').hasMatch(p)&&p=='/company/${widget.brand.slug}/logo'){
      future=fetch(p,false);
    }
  }
  Future<Uint8List?> fetch(String path,bool auth)async{
    try{return await widget.api.bytes(path,auth:auth);}catch(_){return null;}
  }
  @override Widget build(BuildContext context){
    final s=Theme.of(context).colorScheme;
    final fallback=Center(child:CopyText(widget.brand.initials.isEmpty?'ID':widget.brand.initials,
      style:TextStyle(color:widget.brand.deep,fontSize:widget.size*.31,fontWeight:FontWeight.w800)));
    return Semantics(label:'${widget.brand.name} logo',image:true,child:Container(
      width:widget.size,height:widget.size,
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),
        border:Border.all(color:s.outline.withValues(alpha:.65))),
      clipBehavior:Clip.antiAlias,
      child:FutureBuilder<Uint8List?>(future:future,builder:(context,snapshot){
        final data=snapshot.data;
        if(data!=null&&data.isNotEmpty){return Padding(padding:const EdgeInsets.all(7),
          child:Image.memory(data,fit:BoxFit.contain,errorBuilder:(_,__,___)=>fallback));}
        if(snapshot.connectionState==ConnectionState.waiting){return Center(
          child:SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:widget.brand.deep)));}
        return fallback;
      }),
    ));
  }
}

class CompanyIdentityCard extends StatelessWidget {
  final Api api;
  final Map<String,dynamic> data;
  final Object? memberCount;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  const CompanyIdentityCard({super.key,required this.api,required this.data,this.memberCount,this.onTap,this.onMore});
  @override Widget build(BuildContext context){
    final t=Theme.of(context);
    final brand=Brand.from(data);
    final kind=brand.kind=='DemandAggregator'?'Demand Aggregator':brand.kind;
    final slug=brand.slug;
    final rawAddress=data['address']?.toString().trim()??'';
    return TideSurface(onTap:onTap,padding:EdgeInsets.zero,child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(height:9,decoration:BoxDecoration(gradient:LinearGradient(colors:[brand.deep,brand.accent]))),
        Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            CompanyLogo(api:api,brand:brand,companyId:data['id'],size:72),
            const SizedBox(width:13),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              CopyText(brand.name,style:t.textTheme.titleLarge),
              const SizedBox(height:4),
              CopyText(kind,style:t.textTheme.bodySmall?.copyWith(color:t.colorScheme.onSurfaceVariant)),
              if(slug.isNotEmpty)CopyText(slug,style:t.textTheme.bodySmall),
            ])),
            if(onMore==null&&onTap!=null)Icon(Icons.arrow_outward_rounded,color:t.colorScheme.primary,size:20),
          ]),
          const SizedBox(height:12),
          Wrap(spacing:12,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
            if(data['active'] is bool)TideStatus(data['active']==true?'Active':'Inactive'),
            if(memberCount!=null)CopyText('$memberCount members',style:t.textTheme.labelMedium),
          ]),
          if(rawAddress.isNotEmpty)...[const SizedBox(height:12),TideMapLink(address:rawAddress,compact:true)],
          if(onMore!=null)...[const SizedBox(height:12),OutlinedButton.icon(onPressed:onMore,icon:const Icon(Icons.tune_rounded),label:const CopyText('Company actions'))],
        ])),
      ],
    ));
  }
}

class TideAction {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  const TideAction({required this.title,required this.icon,required this.onTap,this.destructive=false});
}

IconData actionIcon(String path,String method){
  final a=path.split('/').last;
  if(method=='GET')return Icons.visibility_outlined;
  if(a.contains('delete')||a.contains('remove')||a.contains('unlink')||a.contains('revoke')||method=='DELETE')return Icons.delete_outline_rounded;
  if(a.contains('edit')||a.contains('update')||a.contains('rename')||method=='PUT')return Icons.edit_outlined;
  if(a.contains('create'))return Icons.add_rounded;
  if(a.contains('assign')||a.contains('attach')||a.contains('grant'))return Icons.person_add_alt_1_outlined;
  if(a.contains('schedule'))return Icons.calendar_month_outlined;
  if(a.contains('otp')||a.contains('password'))return Icons.verified_user_outlined;
  if(a.contains('review')||a.contains('respond'))return Icons.fact_check_outlined;
  if(a.contains('stock'))return Icons.inventory_2_outlined;
  if(a.contains('report'))return Icons.description_outlined;
  if(a.contains('restore')||a.contains('retry'))return Icons.refresh_rounded;
  if(a.contains('active')||a.contains('status'))return Icons.toggle_on_outlined;
  if(a.contains('import'))return Icons.upload_file_outlined;
  return Icons.arrow_outward_rounded;
}

Future<void> showTideActions(BuildContext context,List<TideAction> actions,{String title='Actions'})async{
 if(actions.isEmpty)return;
 final selected=await showTideSheet<TideAction>(context,title:title,subtitle:'${actions.length} available operations',icon:Icons.bolt_rounded,content:(_)=>_TideActionMenu(actions:actions));
 if(selected!=null&&context.mounted)selected.onTap();
}
class _TideActionMenu extends StatefulWidget{
 final List<TideAction> actions;const _TideActionMenu({required this.actions});
 @override State<_TideActionMenu> createState()=>_TideActionMenuState();
}
class _TideActionMenuState extends State<_TideActionMenu>{
 String query='';
 @override Widget build(BuildContext c){
 final t=Theme.of(c);final s=t.colorScheme;
 final matches=widget.actions.where((a)=>tr(c,a.title).toLowerCase().contains(query.trim().toLowerCase())||a.title.toLowerCase().contains(query.trim().toLowerCase())).toList();
 final normal=matches.where((a)=>!a.destructive).toList();final danger=matches.where((a)=>a.destructive).toList();
 Widget tile(TideAction a)=>TideSurface(onTap:()=>Navigator.pop(c,a),padding:const EdgeInsets.all(14),tinted:!a.destructive,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Row(children:[Container(width:44,height:44,decoration:BoxDecoration(color:tideTint(c,a.destructive?s.error:s.primary,.15),borderRadius:BorderRadius.circular(15)),child:Icon(a.icon,color:a.destructive?s.error:s.primary,size:23)),const Spacer(),Icon(Icons.arrow_outward_rounded,color:a.destructive?s.error:s.primary,size:17)]),
 const SizedBox(height:12),CopyText(a.title,style:t.textTheme.titleSmall?.copyWith(color:a.destructive?s.error:null,height:1.25)),
 ]));
 return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 if(widget.actions.length>6)...[TextField(decoration:const InputDecoration(hintText:'Search actions',prefixIcon:Icon(Icons.search_rounded)),onChanged:(v)=>setState(()=>query=v)),const SizedBox(height:14)],
 if(normal.isNotEmpty)...[const TideSection(title:'Operations'),const SizedBox(height:10),TideGrid(maxColumns:2,children:normal.map(tile).toList())],
 if(danger.isNotEmpty)...[const SizedBox(height:18),const TideSection(title:'Manage access or remove'),const SizedBox(height:10),TideGrid(maxColumns:2,children:danger.map(tile).toList())],
 if(matches.isEmpty)const TideEmpty(message:'No matching actions.'),
 ]);
 }
}
/// At most one direct primary action. The rest are available through an
/// icon-led, two-column sheet; no new operation is introduced by this widget.
class TideActionDock extends StatelessWidget {
  final List<TideAction> actions;
  final String title;
  final bool compact;
  const TideActionDock({super.key,required this.actions,this.title='Actions',this.compact=false});
  @override Widget build(BuildContext context){
    if(actions.isEmpty)return const SizedBox.shrink();
    final primary=actions.where((a)=>!a.destructive).firstOrNull;
    final rest=actions.where((a)=>!identical(a,primary)).toList();
    Widget more(List<TideAction> items,String label)=>OutlinedButton.icon(onPressed:()=>showTideActions(context,items,title:title),icon:const Icon(Icons.tune_rounded,size:19),label:CopyText(label));
    if(compact)return Padding(padding:const EdgeInsets.only(top:6),child:Align(alignment:Alignment.centerRight,child:actions.length==1&&!actions.single.destructive?TextButton.icon(onPressed:actions.single.onTap,icon:Icon(actions.single.icon,size:19),label:CopyText(actions.single.title)):more(actions,'Manage actions')));
    return TideSurface(padding:const EdgeInsets.all(8),child:LayoutBuilder(builder:(c,box){
      final main=primary==null?null:FilledButton.icon(onPressed:primary.onTap,icon:Icon(primary.icon,size:20),label:CopyText(primary.title,textAlign:TextAlign.center));
      if(main==null)return SizedBox(width:double.infinity,child:more(actions,'Manage actions'));
      if(rest.isEmpty)return SizedBox(width:double.infinity,child:main);
      final secondary=more(rest,'More actions');
      if(box.maxWidth<380||MediaQuery.textScalerOf(c).scale(14)>17)return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[main,const SizedBox(height:6),secondary]);
      return Row(children:[Expanded(child:main),const SizedBox(width:8),secondary]);
    }));
  }
}
