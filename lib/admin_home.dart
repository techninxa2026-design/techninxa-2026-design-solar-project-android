import 'package:flutter/material.dart';
import 'api.dart';
import 'copy.dart';
import 'theme.dart';
import 'tide_cards.dart';
import 'tide_actions.dart';
import 'tide_editorial.dart';

class AdminHome extends StatefulWidget{
 final Api api;final Brand brand;final int unread;
 final Future<void> Function() openCompanies,openNotifications,register,choose;
 final Future<void> Function(Map<String,dynamic>,Map<String,dynamic>) openCompany;
 const AdminHome({super.key,required this.api,required this.brand,required this.unread,required this.openCompanies,required this.openNotifications,required this.register,required this.choose,required this.openCompany});
 @override State<AdminHome> createState()=>_AdminHomeState();
}
class _AdminHomeState extends State<AdminHome>{
 late Future<Map<String,dynamic>> future=load();String filter='all';
 Future<Map<String,dynamic>> load()async=>obj(await widget.api.get('/companies'));
 Future<void> reload()async{if(!mounted)return;setState(()=>future=load());try{await future;}catch(_){}}
 Future<void> after(Future<void> Function() action)async{await action();if(mounted)await reload();}
 @override Widget build(BuildContext c){
  final t=Theme.of(c);final s=t.colorScheme;final name=widget.api.me['fullName']?.toString().trim()??'';
  return RefreshIndicator(onRefresh:reload,child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(18,14,18,24),children:[
   Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     CopyText('PLATFORM ADMINISTRATION',style:t.textTheme.labelSmall?.copyWith(color:s.primary,letterSpacing:1.5,fontWeight:FontWeight.w800)),
     const SizedBox(height:6),CopyText(name.isEmpty?'Welcome, administrator':'Welcome, '+name,style:t.textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800,height:1.15)),
     const SizedBox(height:5),const CopyText('Manage your solar company network.'),
    ])),const SizedBox(width:8),TideAvatar(name.isEmpty?'Admin':name,size:48)]),
   const SizedBox(height:18),
   FutureBuilder<Map<String,dynamic>>(future:future,builder:(c,snapshot){
    if(snapshot.hasError)return TideNotice(userError(snapshot.error),title:'Unable to load companies',error:true,retry:reload);
    if(!snapshot.hasData)return const TideLoading();
    final data=snapshot.data!;final companies=rows(data['items']);final da=companies.where((r)=>r['companyKind']=='DemandAggregator').length;
    final installers=companies.where((r)=>r['companyKind']=='Installer').length;
    final active=companies.where((r)=>r['active']==true).length;
    final inactive=companies.length-active;final counts=obj(data['memberCounts']);
    final matches=companies.where((r)=>switch(filter){'da'=>r['companyKind']=='DemandAggregator','installer'=>r['companyKind']=='Installer','inactive'=>r['active']!=true,_=>true}).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     _NetworkOverview(total:companies.length,active:active,inactive:inactive,da:da,installers:installers,brand:widget.brand,onOpen:()=>after(widget.openCompanies)),
     const SizedBox(height:20),const TideSection(title:'Manage your network',subtitle:'Choose what you want to do'),const SizedBox(height:10),
     LayoutBuilder(builder:(c,box){
      final tiles=<Widget>[
       _AdminAction(icon:Icons.add_business_rounded,title:'Register company',subtitle:'Add a DA or Installer',onTap:()=>after(widget.register)),
       _AdminAction(icon:Icons.space_dashboard_outlined,title:'Open workspace',subtitle:'Work inside a company',onTap:()=>after(widget.choose)),
      ];
      return box.maxWidth>=280&&MediaQuery.textScalerOf(c).scale(14)<=17?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:tiles[0]),const SizedBox(width:10),Expanded(child:tiles[1])]):Column(children:[tiles[0],const SizedBox(height:10),tiles[1]]);
     }),
     const SizedBox(height:10),TideSurface(onTap:widget.openNotifications,padding:const EdgeInsets.all(13),child:Row(children:[
      const TideGlyph(Icons.notifications_active_outlined,size:44),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CopyText('Notifications',style:t.textTheme.titleSmall),CopyText(widget.unread==0?'No unread notifications':widget.unread.toString()+' unread updates',style:t.textTheme.bodySmall)])),
      if(widget.unread>0)Badge(label:Text(widget.unread.toString())),const SizedBox(width:6),const Icon(Icons.chevron_right_rounded),
     ])),
     const SizedBox(height:24),TideSection(title:'Company directory',subtitle:'Open a company to see its details',trailing:TextButton(onPressed:()=>after(widget.openCompanies),child:const CopyText('View all'))),
     const SizedBox(height:8),Wrap(spacing:6,runSpacing:6,children:[
      for(final x in [('all','All'),('da','DA'),('installer','Installer'),('inactive','Inactive')])ChoiceChip(label:CopyText(x.$2),selected:filter==x.$1,onSelected:(_)=>setState(()=>filter=x.$1)),
     ]),
     const SizedBox(height:10),if(matches.isEmpty)const TideEmpty(message:'No companies in this category.'),
     for(final row in matches.take(5))Padding(padding:const EdgeInsets.only(bottom:9),child:_CompanyRow(api:widget.api,row:row,count:counts[row['id'].toString()],onTap:()=>after(()=>widget.openCompany(row,data)))),
     if(matches.length>5)OutlinedButton.icon(onPressed:()=>after(widget.openCompanies),icon:const Icon(Icons.apartment_outlined),label:const CopyText('View company directory')),
    ]);
   }),
  ]));
 }
}
class _NetworkOverview extends StatelessWidget{
 final int total,active,inactive,da,installers;final Brand brand;final VoidCallback onOpen;
 const _NetworkOverview({required this.total,required this.active,required this.inactive,required this.da,required this.installers,required this.brand,required this.onOpen});
 @override Widget build(BuildContext c){
  final pct=total==0?0.0:active/total;
  return Column(children:[
   ClipRRect(borderRadius:BorderRadius.circular(28),child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[const Color(0xff07334d),brand.deep])),child:Stack(children:[
    Positioned.fill(child:CustomPaint(painter:TideContour(Colors.white.withValues(alpha:.13)))),
    Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Row(children:[const Expanded(child:CopyText('COMPANY NETWORK',style:TextStyle(color:Color(0xffcae9f8),fontSize:11,fontWeight:FontWeight.w800,letterSpacing:1.4))),IconButton(tooltip:'View company directory',onPressed:onOpen,icon:const Icon(Icons.arrow_outward_rounded,color:Colors.white))]),
     CopyText(total.toString(),style:const TextStyle(color:Colors.white,fontSize:52,height:1,fontWeight:FontWeight.w800,letterSpacing:-2)),
     const SizedBox(height:5),const CopyText('Registered companies',style:TextStyle(color:Colors.white,fontSize:15)),
     const SizedBox(height:14),ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(value:pct,minHeight:9,backgroundColor:Colors.white24,valueColor:const AlwaysStoppedAnimation(Color(0xff80e4c6)))),
     const SizedBox(height:10),Wrap(spacing:18,runSpacing:8,children:[_legend(const Color(0xff80e4c6),activuserError(e)+' active'),_legend(Colors.white54,inactivuserError(e)+' inactive')]),
     const SizedBox(height:16),const Divider(color:Colors.white24,height:1),const SizedBox(height:12),
     LayoutBuilder(builder:(c,box){final items=[_metric(c,'Demand Aggregators',da,Icons.solar_power_outlined),_metric(c,'Installers',installers,Icons.engineering_outlined)];return box.maxWidth>=240&&MediaQuery.textScalerOf(c).scale(14)<=17?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:items[0]),const SizedBox(width:12),Expanded(child:items[1])]):Column(children:[items[0],const SizedBox(height:10),items[1]]);}),
    ])),
   ]))),

  ]);
 }
 Widget _legend(Color color,String text)=>Row(mainAxisSize:MainAxisSize.min,children:[Container(width:9,height:9,decoration:BoxDecoration(color:color,shape:BoxShape.circle)),const SizedBox(width:7),CopyText(text,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600,fontSize:13))]);
 Widget _metric(BuildContext c,String label,int count,IconData icon)=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:34,height:34,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.13),borderRadius:BorderRadius.circular(11)),child:Icon(icon,color:Colors.white,size:20)),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CopyText(count.toString(),style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w800,height:1.1)),const SizedBox(height:4),CopyText(label,style:const TextStyle(color:Color(0xffcae9f8),fontSize:12,height:1.2))]))]);
}
class _AdminAction extends StatelessWidget{
 final IconData icon;final String title,subtitle;final VoidCallback onTap;
 const _AdminAction({required this.icon,required this.title,required this.subtitle,required this.onTap});
 @override Widget build(BuildContext c)=>TideSurface(onTap:onTap,tinted:true,padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Row(children:[TideGlyph(icon,size:43),const Spacer(),Icon(Icons.arrow_outward_rounded,size:18,color:Theme.of(c).colorScheme.primary)]),
  const SizedBox(height:12),CopyText(title,style:Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:5),CopyText(subtitle,style:Theme.of(c).textTheme.bodySmall),
 ]));
}
class _CompanyRow extends StatelessWidget{
 final Api api;final Map<String,dynamic> row;final dynamic count;final VoidCallback onTap;
 const _CompanyRow({required this.api,required this.row,required this.count,required this.onTap});
 @override Widget build(BuildContext c){
  final b=Brand.from(row);final t=Theme.of(c);
  return TideSurface(onTap:onTap,padding:const EdgeInsets.all(12),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
   CompanyLogo(api:api,brand:b,companyId:row['id'],size:54),const SizedBox(width:12),
   Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    CopyText(b.name,style:t.textTheme.titleSmall),const SizedBox(height:3),CopyText(b.kind=='DemandAggregator'?'Demand Aggregator':b.kind,style:t.textTheme.bodySmall),
    const SizedBox(height:7),Wrap(spacing:7,runSpacing:6,crossAxisAlignment:WrapCrossAlignment.center,children:[TideStatus(row['active']==true?'Active':'Inactive'),if(count!=null)CopyText(count.toString()+' members',style:t.textTheme.labelSmall)]),
   ])),const SizedBox(width:8),Icon(Icons.chevron_right_rounded,color:t.colorScheme.primary),
  ]));
 }
}
