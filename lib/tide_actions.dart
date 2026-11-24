import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'api.dart';
import 'copy.dart';
import 'theme.dart';
import 'tide_cards.dart';

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
    }else if(RegExp(r'^/company/[A-Za-z0-9-]+/logo$').hasMatch(p)&&p=='/company/'+widget.brand.slug+'/logo'){
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
    return Semantics(label:widget.brand.name+' logo',image:true,child:Container(
      width:widget.size,height:widget.size,
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),
        border:Border.all(color:s.outline.withValues(alpha:.65))),
      clipBehavior:Clip.antiAlias,
      child:FutureBuilder<Uint8List?>(future:future,builder:(context,snapshot){
        final data=snapshot.data;
        if(data!=null&&data.isNotEmpty)return Padding(padding:const EdgeInsets.all(7),
          child:Image.memory(data,fit:BoxFit.contain,errorBuilder:(_,__,___)=>fallback));
        if(snapshot.connectionState==ConnectionState.waiting)return Center(
          child:SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:widget.brand.deep)));
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
            if(onMore!=null)IconButton(tooltip:'Company actions',onPressed:onMore,icon:const Icon(Icons.more_horiz))
            else if(onTap!=null)Icon(Icons.arrow_outward_rounded,color:t.colorScheme.primary,size:20),
          ]),
          const SizedBox(height:12),
          Wrap(spacing:12,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
            if(data['active'] is bool)TideStatus(data['active']==true?'Active':'Inactive'),
            if(memberCount!=null)CopyText('$memberCount members',style:t.textTheme.labelMedium),
          ]),
          if(rawAddress.isNotEmpty)...[const SizedBox(height:12),Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Icon(Icons.location_on_outlined,size:17,color:t.colorScheme.primary),
            const SizedBox(width:7),Expanded(child:CopyText(rawAddress,style:t.textTheme.bodySmall)),
          ])],
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
  final selected=await showModalBottomSheet<TideAction>(
    context:context,isScrollControlled:true,showDragHandle:true,useSafeArea:true,
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(30))),
    builder:(c){
      final t=Theme.of(c);
      final normal=actions.where((a)=>!a.destructive).toList();
      final danger=actions.where((a)=>a.destructive).toList();
      Widget tile(TideAction action)=>TideSurface(
        onTap:()=>Navigator.pop(c,action),padding:const EdgeInsets.all(13),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(action.icon,size:25,color:action.destructive?t.colorScheme.error:t.colorScheme.primary),
          const SizedBox(height:10),
          CopyText(action.title,style:t.textTheme.titleSmall?.copyWith(
            color:action.destructive?t.colorScheme.error:null)),
        ]),
      );
      return SafeArea(top:false,child:ConstrainedBox(
        constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(c).height*.74),
        child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(20,0,20,24),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            CopyText(title,style:t.textTheme.headlineSmall),
            const SizedBox(height:5),
            CopyText('Choose what you want to do',style:t.textTheme.bodySmall),
            const SizedBox(height:18),
            if(normal.isNotEmpty)TideGrid(maxColumns:2,children:normal.map(tile).toList()),
            if(danger.isNotEmpty)...[
              if(normal.isNotEmpty)const SizedBox(height:20),
              CopyText('Manage access or remove',style:t.textTheme.labelLarge?.copyWith(color:t.colorScheme.error)),
              const SizedBox(height:10),
              TideGrid(maxColumns:2,children:danger.map(tile).toList()),
            ],
          ])),
      ));
    });
  if(selected!=null&&context.mounted)selected.onTap();
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
    if(compact)return Align(alignment:Alignment.centerRight,child:IconButton.filledTonal(tooltip:'Actions',onPressed:()=>showTideActions(context,actions,title:title),icon:const Icon(Icons.more_horiz_rounded)));
    return TideSurface(padding:const EdgeInsets.all(8),child:Row(children:[
      if(primary!=null)Expanded(child:FilledButton.icon(
        onPressed:primary.onTap,icon:Icon(primary.icon,size:20),
        label:CopyText(primary.title,textAlign:TextAlign.center))),
      if(primary!=null&&rest.isNotEmpty)const SizedBox(width:8),
      if(rest.isNotEmpty&&primary!=null)IconButton.filledTonal(
        tooltip:'More actions',onPressed:()=>showTideActions(context,rest,title:title),
        icon:const Icon(Icons.more_horiz_rounded)),
      if(primary==null)Expanded(child:OutlinedButton.icon(
        onPressed:()=>showTideActions(context,actions,title:title),
        icon:const Icon(Icons.more_horiz_rounded),label:const CopyText('Actions'))),
    ]));
  }
}
