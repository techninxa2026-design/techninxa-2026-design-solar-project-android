import 'copy.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'catalog.dart';
import 'theme.dart';
import 'tide_cards.dart';
import 'tide_actions.dart';
import 'tide_editorial.dart';
import 'tide_interactions.dart';
import 'form_parity.dart';
import 'record_presentation.dart';
import 'workspace_search.dart';
import 'hierarchy_board.dart';

void toast(BuildContext c,String text)=>ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:CopyText(text)));
Future<bool> confirmAction(BuildContext c,String title,{String message='This updates the live IDCOLDA system. Review your selection before continuing.'}) async => await showDialog<bool>(context:c,builder:(c)=>AlertDialog(title:CopyText(title),content:CopyText(message),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const CopyText('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const CopyText('Confirm'))]))??false;
String heading(Map<String,dynamic> row)=>['name','fullName','title','taskTitle','packageName','customerName','productName','warehouseName','value','roleName','requestedDesignation','accessibility','email','report','body','kind'].map((k)=>row[k]).where((x)=>x!=null&&x.toString().trim().isNotEmpty).map((x)=>x.toString()).firstOrNull??'Record ${row['id']??''}';
String summary(Map<String,dynamic> r)=>['companyKind','status','progress','taskType','sku','bess','inverter','unit','address','deliveryStatus','email','amount','createdUtc'].where((k)=>r[k]!=null&&r[k].toString().isNotEmpty).take(3).map((k)=>r[k].toString()).join(' · ');
List<Map<String,dynamic>> listOf(Map<String,dynamic> data,String key){if(data[key] is List)return rows(data[key]);for(final k in ['territory','selections']){final o=obj(data[k]);if(o[key] is List)return rows(o[key]);}return [];}
Map<String,dynamic> merged(Map<String,dynamic> a,Map<String,dynamic> b)=>{...a,...b,'territory':{...obj(a['territory']),...obj(b['territory'])},'selections':{...obj(a['selections']),...obj(b['selections'])}};
String norm(String s)=>s.toLowerCase().replaceFirst('form.','');
dynamic caseValue(Map<String,dynamic> data,String k)=>data.entries.where((e)=>norm(e.key)==norm(k)).map((e)=>e.value).firstOrNull;

String? recordStatus(Map<String,dynamic> row){
  if(row['status']!=null)return row['status'].toString();
  if(row['isArchived'] is bool)return row['isArchived']==true?'Archived':'Active';
  if(row['isRead'] is bool)return row['isRead']==true?'Read':'Unread';
  if(row['active'] is bool)return row['active']==true?'Active':'Inactive';
  return null;
}
IconData recordIcon(String module,String section)=>switch(module){
  'companies'=>Icons.apartment_rounded,'roles'=>Icons.badge_outlined,
  'people'=>section=='grants'?Icons.verified_user_outlined:Icons.groups_outlined,
  'accounts'||'applications'=>Icons.assignment_ind_outlined,
  'departments'||'hierarchy'=>Icons.account_tree_outlined,
  'territories'=>Icons.location_on_outlined,'warehouses'=>Icons.warehouse_outlined,
  'products'=>Icons.inventory_2_outlined,'stock'=>Icons.layers_outlined,
  'clients'=>Icons.person_outline,'packages'=>Icons.solar_power_outlined,
  'tasks'=>Icons.task_alt_rounded,'dispatches'=>Icons.local_shipping_outlined,
  'sales'=>Icons.payments_outlined,'notifications'=>Icons.notifications_none,
  'profile'=>Icons.account_circle_outlined,_=>Icons.folder_open_outlined,
};
String prettyValue(String key,dynamic value){
  if(key=='companyKind'&&value=='DemandAggregator')return 'Demand Aggregator';
  if(value is bool)return value?'Yes':'No';
  if(value is List)return value.join(', ');
  if(['amount','unitPrice'].contains(key))return '৳ $value';
  if(key.endsWith('Utc')&&value is String){
    final d=DateTime.tryParse(value);
    if(d!=null){final local=d.toLocal();final date=local.toIso8601String();return '${date.substring(0,10)} · ${date.substring(11,16)}';}
  }
  return value.toString();
}
class BusinessRecordCard extends StatelessWidget {
  final String module,section;
  final Map<String,dynamic> data;
  final VoidCallback? onTap;
  final Widget? media;
  const BusinessRecordCard({super.key,required this.module,required this.section,required this.data,this.onTap,this.media});
  String? value(String k){final x=data[k];return x==null||x.toString().trim().isEmpty?null:prettyValue(k,x);}
  @override Widget build(BuildContext c){
    final t=Theme.of(c);final s=t.colorScheme;
    final title=module=='stock'?(data['productName']?.toString()??heading(data)):heading(data);
    final status=recordStatus(data);
    final person=['clients','people','accounts','applications'].contains(module)&&!['grants','memberScopes'].contains(section);
    final finance=module=='sales'||module=='stock';
    final work=module=='tasks'||module=='dispatches';
    final item=module=='products'||module=='packages';
    final keys=switch(module){
      'companies'=>['companyKind','slug','address'],
      'roles'=>['description'],
      'people'=>['roleName','accessibility','email','assignedUtc'],
      'accounts'||'applications'=>['email','requestedDesignation','deliveryStatus'],
      'departments'=>['roleName','departmentName'],
      'hierarchy'=>['roleName','departmentName','userName'],
      'territories'=>['zoneName','districtName','areaName','address'],
      'warehouses'=>['address','zoneName','districtName'],
      'products'=>['sku','unitPrice','unit','category'],
      'stock'=>['onHand','unit','warehouseName'],
      'clients'=>['mobile','address','productInterest'],
      'packages'=>['bess','inverter','kind','unitPrice','unit'],
      'tasks'=>['taskType','customerAddress','packageNameSnapshot','createdUtc'],
      'dispatches'=>['progress','scheduledInstallationDate','customerAddress','daOfferedInstallationDate','taskType'],
      'sales'=>['amount','packageName','installerCompanyName','completedUtc'],
      'notifications'=>['category','createdUtc','message','body'],
      _=>['email','address','description','createdUtc'],
    };
    final facts=keys.where((k)=>value(k)!=null&&value(k)!=title).take(4).toList();
    final metric=facts.where((k)=>['amount','unitPrice','onHand'].contains(k)).firstOrNull;
    final rest=facts.where((k)=>k!=metric).toList();
    final date=rest.where((k)=>k=='scheduledInstallationDate'||k=='daOfferedInstallationDate'||k=='createdUtc'||k=='completedUtc').firstOrNull;
    final dateText=date==null?null:value(date);
    Widget header({bool circle=false})=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      media??(circle?TideAvatar(title):TideGlyph(recordIcon(module,section),size:item?58:46)),
      const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        CopyText(title,style:t.textTheme.titleMedium?.copyWith(fontSize:17,height:1.25)),
        if(status!=null)...[const SizedBox(height:7),TideStatus(status)],
      ])),if(onTap!=null)Padding(padding:const EdgeInsets.only(left:6,top:3),child:Icon(Icons.arrow_outward_rounded,color:s.primary,size:17)),
    ]);
    Widget fact(String k)=>tideAddressKey(k)?TideMapLink(address:value(k),gps:data['gpsLocationUrl']?.toString(),compact:true):TideFieldGroup(label:label(k),value:value(k)!,icon:switch(k){
      'mobile'=>Icons.phone_outlined,'address'=>Icons.location_on_outlined,'email'=>Icons.mail_outline,
      'warehouseName'=>Icons.warehouse_outlined,'bess'=>Icons.battery_charging_full,
      'inverter'=>Icons.bolt_rounded,'sku'=>Icons.qr_code_rounded,
      'scheduledInstallationDate'||'daOfferedInstallationDate'||'createdUtc'||'completedUtc'=>Icons.calendar_month_outlined,
      _=>Icons.short_text_rounded});
    Widget factsGrid(List<String> ks)=>LayoutBuilder(builder:(c,bounds){
      final columns=bounds.maxWidth>=350&&MediaQuery.textScalerOf(c).scale(14)<=17?2:1;
      return Wrap(spacing:12,runSpacing:14,children:ks.map((k)=>SizedBox(width:tideAddressKey(k)?bounds.maxWidth:(bounds.maxWidth-(columns-1)*12)/columns,child:fact(k))).toList());
    });
    if(finance&&metric!=null){
      return TideSurface(onTap:onTap,padding:EdgeInsets.zero,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(gradient:LinearGradient(colors:[contrast(s.primary),contrast(const Color(0xff087eb1))])),child:Stack(children:[
          Positioned.fill(child:CustomPaint(painter:TideContour(Colors.white.withValues(alpha:.13)))),
          Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Icon(recordIcon(module,section),color:Colors.white,size:22),const SizedBox(width:8),Expanded(child:CopyText(label(metric),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600))),if(onTap!=null)const Icon(Icons.arrow_outward,color:Colors.white,size:18)]),
            const SizedBox(height:10),CopyText(value(metric)!,style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w900,letterSpacing:-.6)),
          ]),
        ])),
        Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          CopyText(title,style:t.textTheme.titleMedium),if(status!=null)...[const SizedBox(height:7),TideStatus(status)],
          if(rest.isNotEmpty)...[const SizedBox(height:13),factsGrid(rest)],
        ])),
      ]));
    }
    if(work){
      return TideSurface(onTap:onTap,padding:EdgeInsets.zero,child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(width:5,height:82,margin:const EdgeInsets.only(top:18),decoration:BoxDecoration(color:s.primary,borderRadius:const BorderRadius.horizontal(right:Radius.circular(8)))),
        Expanded(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          header(),
          if(dateText!=null)...[const SizedBox(height:14),Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:tideTint(c,s.primary,.10),borderRadius:BorderRadius.circular(16)),child:fact(date!))],
          if(rest.any((k)=>k!=date))...[const SizedBox(height:14),factsGrid(rest.where((k)=>k!=date).toList())],
        ]))),
      ]));
    }
    if(person){
      return TideSurface(onTap:onTap,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        header(circle:true),
        if(rest.isNotEmpty)...[const SizedBox(height:14),factsGrid(rest)],
      ]));
    }
    if(module=='notifications'){
      return TideSurface(onTap:onTap,tinted:data['isRead']==false,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        header(),
        for(final k in rest)...[const SizedBox(height:9),if(k=='message'||k=='body')CopyText(value(k)!,style:t.textTheme.bodyMedium)else fact(k)],
      ]));
    }
    return TideSurface(onTap:onTap,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      header(),
      if(metric!=null)...[const SizedBox(height:13),Container(width:double.infinity,padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:tideTint(c,s.primary,.09),borderRadius:BorderRadius.circular(16)),child:TideFact(label:label(metric),value:value(metric)!,emphasis:true))],
      if(rest.isNotEmpty)...[const SizedBox(height:14),factsGrid(rest)],
    ]));
  }
}

class ActionSpec{final String method,path;final Map<String,dynamic> initial;final String? title;const ActionSpec(this.method,this.path,{this.initial=const{},this.title});}
TideAction presentAction(Catalog catalog,ActionSpec op,VoidCallback onTap){final o=catalog.op(op.method,op.path);final title=op.title??o.title;return TideAction(title:title,icon:actionIcon(op.path,op.method),onTap:onTap,destructive:o.destructive||title.toLowerCase().startsWith('reject')||title.toLowerCase().startsWith('deactivate')||title.toLowerCase().startsWith('revoke'));}
ActionSpec cmd(String group,String action,{Map<String,dynamic> initial=const{},String? title})=>ActionSpec('POST','/commands/$group/$action',initial:initial,title:title);

// Explicit contexts: no arbitrary URLs, no hidden privilege escalation. The
// server is authoritative even when a client control is visible.
Future<void> openWorkspaceSearch(BuildContext context,Api api,Catalog catalog,Brand brand,{VoidCallback? home})async{
 final destination=await findWorkspacePage(context,api);if(destination==null||!context.mounted)return;
 if(destination.module=='home'){if(home!=null){home();}else{Navigator.of(context).popUntil((r)=>r.isFirst);}return;}
 final module=destination.module=='overview'?const Module('overview','Operations overview','Your authorized organization operations','/organization',[]):modules.where((m)=>m.key==destination.module).firstOrNull;
 if(module==null)return;
 await Navigator.push(context,MaterialPageRoute(builder:(_)=>ModulePage(api:api,catalog:catalog,module:module,brand:brand,power:destination.power,focus:destination.focus,displayTitle:destination.title)));
}
class ModulePage extends StatefulWidget {final Api api;final Catalog catalog;final Module module;final Brand brand;final String? power,focus,displayTitle;const ModulePage({super.key,required this.api,required this.catalog,required this.module,required this.brand,this.power,this.focus,this.displayTitle});@override State<ModulePage> createState()=>_ModulePageState();}
class _ModulePageState extends State<ModulePage>{late Future<Map<String,dynamic>> future=load();String filter='',tab='assigned',taskStatus='all';bool archived=false;bool hierarchyBusy=false;int page=1;final search=TextEditingController();Api get a=>widget.api;String get key=>widget.module.key;bool has(String p)=>a.powers.contains(p);bool flag(Map<String,dynamic> d,String k)=>d[k]==true;
 Future<Map<String,dynamic>> load()async {final m=widget.module;final q=<String,dynamic>{};if(widget.power!=null&&['/organization','/inventory','/tasks','/departments','/packages'].contains(m.path))q['power']=widget.power;if(key=='dispatches')q['tab']=tab;if(key=='clients'){q['archived']=archived;if(filter.isNotEmpty)q['q']=filter;}if(key=='sales'){q['page']=page;if(filter.isNotEmpty)q['q']=filter;}if(key=='notifications'){q['page']=page;if(filter=='unread'||filter=='read')q['filter']=filter;}final d=obj(await a.get(widget.focus=='departmentMembers'?'/departments/members':m.path,query:q));if(widget.focus=='departmentMembers'){d['departmentMembers']=d['members'];d['departmentUsers']=d['users'];d['canCreate']=true;}if(key=='departments'&&flag(d,'canCreate')){try{final x=obj(await a.get('/departments/members'));d.addAll({'departmentUsers':x['users'],'departmentMembers':x['members']});}catch(_) {}}if(key=='sales'){try{d['summary']=await a.get('/sales/summary');}catch(_) {}}return d;}
 Future<void> saveHierarchy(HierarchyChange change)async{
  if(hierarchyBusy)return;setState(()=>hierarchyBusy=true);
  try{
   if(!await confirmAction(context,'Review hierarchy change',message:change.summary+'\n\nThis changes real reporting records. It does not automatically grant accessibility.'))return;
   if(!mounted)return;
   await a.request('POST','/commands/hierarchy/'+change.action,mode:'urlencoded',data:change.payload);
   if(mounted){toast(context,'Hierarchy saved securely.');reload();}
  }catch(e){if(mounted){toast(context,'Not saved: '+e.toString());reload();}}
  finally{if(mounted)setState(()=>hierarchyBusy=false);}
 }
 void reload(){if(mounted)setState(()=>future=load());}
 @override void dispose(){search.dispose();super.dispose();}
 Future<void> perform(ActionSpec action,Map<String,dynamic> source,{Map<String,dynamic> record=const{}})async {final o=widget.catalog.op(action.method,action.path);final result=await Navigator.push<dynamic>(context,MaterialPageRoute(builder:(_)=>OperationPage(api:a,operation:o,title:action.title,initial:{...record,...action.initial},source:source)));if(!mounted)return;if(result is OperationResult&&result.changed){if(action.path.endsWith('/change-password')){await a.clear();return;}reload();if(action.path.endsWith('/create-initial')){final id=obj(result.data)['id'];if(id!=null)await perform(ActionSpec('GET','/departments/initial-accounts/{id}/handoff',initial:{'id':id}),source);else toast(context,'Account saved. Open the authorized handoff using its returned record.');}if(action.path.endsWith('/review')&&action.initial['approve']==true){final id=record['id'];if(id!=null)await perform(ActionSpec('GET','/departments/applications/{id}/confirmation',initial:{'id':id}),source);}}}
 List<ActionSpec> createActions(Map<String,dynamic> d){if(widget.focus=='grants')return [if(flag(d,'canDelegate'))cmd('organization','grant-power')];if(widget.focus=='departmentMembers')return [cmd('departments','assign-member')];return switch(key){
 'companies'=>[cmd('companies','create',initial:{'PrimaryColor':'#234A83','AccentColor':'#35B7C7'},title:'Register company')],
 'roles'=>[if(flag(d,'canRoles'))cmd('organization','create-role')],
 'people'=>[if(flag(d,'canPeople'))cmd('organization','create-role-user'),if(flag(d,'canDelegate'))cmd('organization','grant-power')],
 'accounts'=>[if(flag(d,'canApprove'))cmd('departments','create-initial',title:'Create initial account')],
 'departments'=>[if(flag(d,'canCreate'))cmd('departments','create',initial:{'Track':'General'}),if(flag(d,'canCreate'))cmd('departments','assign-member')],
 'hierarchy'=>[cmd('hierarchy','create-position')],
 'territories'=>[if(flag(d,'canZone'))cmd('organization','create-zone'),if(flag(d,'canDistrict'))cmd('organization','assign-district'),if(flag(d,'canArea'))cmd('organization','create-area',title:'Create thana'),if(flag(d,'canBranch'))cmd('organization','create-branch')],
 'warehouses'=>[if(flag(d,'canWarehouse'))cmd('inventory','create-warehouse')],
 'products'=>[if(flag(d,'canProduct'))... [cmd('inventory','create-product'),cmd('inventory','import-products'),const ActionSpec('GET','/inventory/products/import-template',title:'Download import template')]],
 'stock'=>[if(flag(d,'canAssign'))cmd('inventory','assign-product')],
 'clients'=>[if(flag(d,'canCreate'))const ActionSpec('POST','/clients',title:'Create client')],
 'packages'=>[for(final kind in ['PackageName','Bess','Inverter'])cmd('packages','create-parameter',initial:{'kind':kind},title:'Add '+(kind=='PackageName'?'package name':kind=='Bess'?'BESS':'inverter')),cmd('packages','create-product',initial:{'Unit':'piece','InitialQuantity':'0'}),cmd('packages','create-package')],
 'tasks'=>[if(flag(d,'canCreate'))cmd('tasks','create',title:'Create task')],
 'notifications'=>[const ActionSpec('POST','/notifications/read-all',title:'Mark all as read'),const ActionSpec('POST','/notifications/clear-read',title:'Clear read notifications')],
 'profile'=>[cmd('profile','save',initial:{'Form.FullName':d['fullName'],'Form.WhatsApp':d['whatsApp']??d['whatsapp']},title:'Edit profile'),cmd('profile','change-password'),if(d['hasFront']==true)const ActionSpec('GET','/profile/photo/{side}',initial:{'side':'front'},title:'View NID front'),if(d['hasBack']==true)const ActionSpec('GET','/profile/photo/{side}',initial:{'side':'back'},title:'View NID back')],
 _=>[]};}
 List<String> sections(){if(widget.focus=='grants')return ['grants'];if(widget.focus=='departmentMembers')return ['departmentMembers'];if(key=='territories'&&widget.power!=null)return switch(widget.power){'zone.create'=>['zones'],'district.assign'=>['links'],'area.create'=>['areas'],'branch.create'=>['branches'],_=>['zones','districts','links','areas','branches']};return switch(key){'overview'=>['roles','members','zones','branches'],'companies'=>['items'],'roles'=>['roles'],'people'=>['members','staffAccounts','memberScopes','grants'],'accounts'=>['requests'],'applications'=>['requests'],'departments'=>['departments','departmentMembers'],'hierarchy'=>['positions','departments'],'territories'=>['zones','districts','links','areas','branches'],'warehouses'=>['warehouses'],'products'=>['products'],'stock'=>['inventory'],'clients'=>['items'],'packages'=>['packages','parameters','products'],'tasks'=>['tasks'],'dispatches'=>['items'],'sales'=>['items'],'notifications'=>['items'],_=>[]};}
 String sectionTitle(String s)=>s=='items'?widget.module.title:s=='areas'?'Thanas':s=='links'?'District links':s=='memberScopes'?'Territory scopes':s=='grants'?'Accessibility grants':label(s);
 Future<void> details(Map<String,dynamic> r,String section,Map<String,dynamic> d)async{final id=r['id'];String? path;switch(key){case 'companies':path='/companies/$id';case 'clients':path='/clients/$id';case 'tasks':path='/tasks/$id';case 'dispatches':path='/dispatches/$id';case 'sales':path='/sales/$id';case 'people':if(section=='members'||section=='staffAccounts')if((d['viewableTeamProfileIds'] as List? ?? []).contains(r['userId']))path='/organization/members/${r['userId']}';}
 final result=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>RecordPage(api:a,catalog:widget.catalog,module:widget.module,section:section,record:r,source:d,path:path,brand:widget.brand,archived:archived)));if(result==true)reload();}
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:CopyText(widget.displayTitle??widget.module.title,maxLines:1,overflow:TextOverflow.ellipsis),actions:[IconButton(tooltip:'Find a page',onPressed:()=>openWorkspaceSearch(context,a,widget.catalog,widget.brand),icon:const Icon(Icons.search_rounded)),IconButton(tooltip:'Refresh',onPressed:reload,icon:const Icon(Icons.refresh))]),body:FlowCanvas(brand:widget.brand,dark:Theme.of(c).brightness==Brightness.dark,child:FutureBuilder<Map<String,dynamic>>(future:future,builder:(c,s){if(s.connectionState==ConnectionState.waiting&&!s.hasData)return const TideLoading();if(s.hasError)return Center(child:Padding(padding:const EdgeInsets.all(18),child:TideNotice(s.error.toString(),title:'Unable to load records',error:true,retry:reload)));final d=s.data??{};if(key=='hierarchy')return ListView(padding:const EdgeInsets.all(14),children:[HierarchyBoard(data:d,busy:hierarchyBusy,onChange:saveHierarchy,onCreate:()=>perform(cmd('hierarchy','create-position'),d),onEdit:(row,kind)=>details(row,kind=='position'?'positions':'departments',d))]);final acts=createActions(d);return RefreshIndicator(onRefresh:()async{reload();try{await future;}catch(_){}},child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.all(16),children:[TideBanner(eyebrow:'WORKSPACE',title:widget.displayTitle??widget.module.title,subtitle:widget.module.description,icon:recordIcon(key,''),brand:widget.brand),const SizedBox(height:16),if(key=='tasks')TideSegments<String>(segments:const [ButtonSegment(value:'all',label:CopyText('All')),ButtonSegment(value:'Open',label:CopyText('Open')),ButtonSegment(value:'InProgress',label:CopyText('In progress')),ButtonSegment(value:'Completed',label:CopyText('Completed'))],selected:{taskStatus},onSelectionChanged:(v)=>setState(()=>taskStatus=v.first)),if(key=='clients')TideSegments<bool>(segments:const [ButtonSegment(value:false,label:CopyText('Active')),ButtonSegment(value:true,label:CopyText('Archived'))],selected:{archived},onSelectionChanged:(v){setState(()=>archived=v.first);reload();}),if(key=='dispatches')TideSegments<String>(segments:const [ButtonSegment(value:'assigned',label:CopyText('Assigned')),ButtonSegment(value:'completed',label:CopyText('Completed')),ButtonSegment(value:'rejected',label:CopyText('Rejected'))],selected:{tab},onSelectionChanged:(v){setState(()=>tab=v.first);reload();}),if(key=='notifications')TideSegments<String>(segments:const [ButtonSegment(value:'',label:CopyText('All')),ButtonSegment(value:'unread',label:CopyText('Unread')),ButtonSegment(value:'read',label:CopyText('Read'))],selected:{filter},onSelectionChanged:(v){setState((){filter=v.first;page=1;});reload();}),if(key!='profile'&&key!='notifications')Padding(padding:const EdgeInsets.only(top:12),child:TextField(controller:search,decoration:InputDecoration(hintText:'Search records',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(onPressed:(){search.clear();setState(()=>filter='');reload();},icon:const Icon(Icons.clear))),onChanged:(v){setState(()=>filter=v);},onSubmitted:(_){if(key=='clients'||key=='sales'){page=1;reload();}})),if(key=='sales'&&d['summary']!=null)...[const SizedBox(height:12),SalesPeriods(data:obj(d['summary']),brand:widget.brand)],if(key=='profile')... [const SizedBox(height:12),DetailPanel(data:d)],if(key=='accounts'&&d['applicationLink']!=null)...[const SizedBox(height:12),Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CopyText('Share application link',style:Theme.of(c).textTheme.titleMedium),SelectableText('${d['applicationLink']}'),TextButton.icon(onPressed:()=>Clipboard.setData(ClipboardData(text:'${d['applicationLink']}')),icon:const Icon(Icons.copy),label:const CopyText('Copy link'))]))],if(acts.isNotEmpty)...[const SizedBox(height:16),TideActionDock(title:widget.module.title,actions:acts.map((op)=>presentAction(widget.catalog,op,()=>perform(op,d))).toList())],for(final section in sections())... [const SizedBox(height:20),TideSection(title:sectionTitle(section)),const SizedBox(height:10),...((){final entries=listOf(d,section).where((r)=>filter.isEmpty||key=='notifications'||r.values.any((v)=>v.toString().toLowerCase().contains(filter.toLowerCase()))).where((r)=>key!='tasks'||section!='tasks'||taskStatus=='all'||effectiveTaskStatus(r,d['completedTaskIds'] as List? ?? [])==taskStatus).map((r)=>key=='tasks'&&section=='tasks'?{...r,'status':effectiveTaskStatus(r,d['completedTaskIds'] as List? ?? [])}:r).toList();return entries.isEmpty?<Widget>[const TideEmpty()]:entries.map<Widget>((r)=>Padding(padding:const EdgeInsets.only(bottom:12),child:key=='companies'?CompanyIdentityCard(key:ValueKey('company-'+r['id'].toString()+'-'+identityHashCode(d).toString()),api:a,data:r,memberCount:obj(d['memberCounts'])[r['id'].toString()],onTap:()=>details(r,section,d)):BusinessRecordCard(module:key,section:section,data:displayRecord(r,{...d,'navigation':a.me['navigation']}),media:key=='products'&&r['id'] is int&&(d['productPhotoIds'] as List? ?? []).contains(r['id'])?TideProductPhoto(api:a,id:r['id'] as int):null,onTap:()=>details(r,section,d)))).toList();})()],if(key=='sales'||key=='notifications')Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[TextButton(onPressed:page<=1?null:(){page--;reload();},child:const CopyText('Previous')),CopyText('Page $page'),TextButton(onPressed:page*(d['pageSize'] as int? ??25)>=(d['totalCount'] as int? ??0)?null:(){page++;reload();},child:const CopyText('Next'))]),const SizedBox(height:20)]));})));
}
class SalesPeriods extends StatefulWidget{final Map<String,dynamic> data;final Brand brand;const SalesPeriods({super.key,required this.data,required this.brand});@override State<SalesPeriods> createState()=>_SalesPeriodsState();}
class _SalesPeriodsState extends State<SalesPeriods>{String period='month';@override Widget build(BuildContext c){final d=obj(widget.data[period]);return Column(children:[TideSegments<String>(segments:const [ButtonSegment(value:'today',label:CopyText('Day')),ButtonSegment(value:'week',label:CopyText('Week')),ButtonSegment(value:'month',label:CopyText('Month')),ButtonSegment(value:'year',label:CopyText('Year'))],selected:{period},onSelectionChanged:(v)=>setState(()=>period=v.first)),const SizedBox(height:12),TideBanner(brand:widget.brand,eyebrow:label(period).toUpperCase(),title:'৳ ${d['amount']??'—'}',subtitle:'Sales recorded for the selected period',icon:Icons.payments_outlined),const SizedBox(height:12),TideGrid(maxColumns:2,children:[TideMetric(label:'Sales records',value:'${d['count']??'—'}',icon:Icons.receipt_long_outlined),TideMetric(label:'Unpriced records',value:'${d['unpriced']??'—'}',icon:Icons.info_outline)])]);}}
class DetailPanel extends StatelessWidget {
  final Map<String,dynamic> data;
  const DetailPanel({super.key,required this.data});
  @override Widget build(BuildContext context){
    final t=Theme.of(context);
    final entries=data.entries.where((e)=>e.value!=null&&e.value.toString().isNotEmpty&&
      !internalDisplayField(e.key)&&!['packageProductsJson','referrerNamesJson','temporaryPassword','password','refreshToken','accessToken','workspaceTicket','logoUrl'].contains(e.key)&&
      e.value is! Map&&!(e.value is List&&(e.value as List).any((x)=>x is Map))).toList();
    if(entries.isEmpty)return const TideEmpty(message:'No additional details.');
    final groups=<String,List<MapEntry<String,dynamic>>>{};
    for(final e in entries){
      final k=e.key.toLowerCase();
      final g=k.contains('email')||k.contains('mobile')||k.contains('phone')||k.contains('whatsapp')||k.contains('address')||k.contains('gps')?'Contact & location':
        k.contains('date')||k.endsWith('utc')?'Dates & activity':
        k.contains('amount')||k.contains('price')||k.contains('quantity')||k=='onhand'||k=='unit'?'Commercial details':
        k.contains('status')||k.contains('active')||k.contains('approved')||k.contains('role')||k.contains('power')?'Status & access':
        k.endsWith('id')||k.endsWith('code')?'References':'Overview';
      (groups[g]??=[]).add(e);
    }
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const TideSection(title:'Record details'),
      for(final group in groups.entries)...[
        const SizedBox(height:12),
        TideSurface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[TideGlyph(switch(group.key){
            'Contact & location'=>Icons.contact_phone_outlined,'Dates & activity'=>Icons.calendar_month_outlined,
            'Commercial details'=>Icons.payments_outlined,'Status & access'=>Icons.verified_user_outlined,
            'References'=>Icons.tag_rounded,_=>Icons.article_outlined},size:36),
            const SizedBox(width:10),Expanded(child:CopyText(group.key,style:t.textTheme.titleMedium))]),
          const SizedBox(height:13),
          for(var i=0;i<group.value.length;i++)...[
            if(i>0)Divider(height:22,color:t.colorScheme.outline.withValues(alpha:.32)),
            CopyText(label(group.value[i].key),style:t.textTheme.labelMedium?.copyWith(color:t.colorScheme.onSurfaceVariant)),
            const SizedBox(height:5),
            if(['primarycolor','accentcolor'].contains(group.value[i].key.toLowerCase()))BrandColorPreview(value:group.value[i].value.toString(),title:label(group.value[i].key))else if(tideAddressKey(group.value[i].key))TideMapLink(address:group.value[i].value.toString(),gps:data['gpsLocationUrl']?.toString())else if(group.value[i].key.toLowerCase()=='gpslocationurl')TideMapLink(gps:group.value[i].value.toString())else SelectableText(prettyValue(group.value[i].key,group.value[i].value),style:t.textTheme.bodyLarge?.copyWith(fontWeight:FontWeight.w600)),
          ],
        ])),
      ],
    ]);
  }
}
class RecordPage extends StatefulWidget{final Api api;final Catalog catalog;final Module module;final String section;final Map<String,dynamic> record,source;final String? path;final Brand brand;final bool archived;const RecordPage({super.key,required this.api,required this.catalog,required this.module,required this.section,required this.record,required this.source,required this.path,required this.brand,required this.archived});@override State<RecordPage> createState()=>_RecordPageState();}
class _RecordPageState extends State<RecordPage>{late Future<Map<String,dynamic>> future=load();bool changed=false;Api get a=>widget.api;String get key=>widget.module.key;String get section=>widget.section;Map<String,dynamic> get r=>widget.record;dynamic get id=>r['id'];bool has(String p)=>a.powers.contains(p);bool f(Map<String,dynamic>d,String k)=>d[k]==true;
 Future<Map<String,dynamic>> load()async=>widget.path==null?<String,dynamic>{}:obj(await a.get(widget.path!));
 void reload(){if(mounted)setState(()=>future=load());}
 Future<void> run(ActionSpec op,Map<String,dynamic> d,Map<String,dynamic> current)async {final o=widget.catalog.op(op.method,op.path);final res=await Navigator.push<dynamic>(context,MaterialPageRoute(builder:(_)=>OperationPage(api:a,operation:o,title:op.title,initial:{...current,...op.initial},source:merged(widget.source,d))));if(!mounted)return;if(res is OperationResult&&res.changed){changed=true;if(op.path=='/notifications/{id}/open'){await openNotification(obj(res.data));if(mounted)Navigator.pop(context,true);return;}if(o.destructive||o.path.endsWith('/restore')||o.path.endsWith('/archive')){Navigator.pop(context,true);return;}if(widget.path==null){Navigator.pop(context,true);return;}reload();}}
 Future<void> openNotification(Map<String,dynamic> target)async{final key=switch(target['destination']){'clients'=>'clients','packages'=>'packages','inventory'=>'stock','applications'=>'applications','hierarchy'=>'hierarchy','tasks'=>'tasks','dispatches'=>'dispatches','organization'=>'people','companies'=>'companies',_=>''};final m=modules.where((m)=>m.key==key&&visible(m,a)).firstOrNull;if(m==null){toast(context,'Related destination is unavailable for your account.');return;}final id=target['recordId'];final detail=['clients','tasks','dispatches','companies'].contains(key)&&id is int&&id>0;await Navigator.push(context,MaterialPageRoute(builder:(_)=>detail?RecordPage(api:a,catalog:widget.catalog,module:m,section:'items',record:{'id':id},source:{},path:'${m.path}/$id',brand:widget.brand,archived:false):ModulePage(api:a,catalog:widget.catalog,module:m,brand:widget.brand)));}
 List<ActionSpec> actions(Map<String,dynamic> d,Map<String,dynamic> current){final src=widget.source;final recId=current['id']??id;final result=<ActionSpec>[];void add(String g,String ac,{Map<String,dynamic> v=const{},String? title})=>result.add(cmd(g,ac,initial:v,title:title));void native(String method,String path,{Map<String,dynamic> v=const{},String? title})=>result.add(ActionSpec(method,path,initial:v,title:title));switch(key){
 case 'companies':if(a.superAdmin){add('companies','edit',v:{...current,'id':recId},title:'Edit company & branding');add('companies','set-active',v:{'id':recId,'active':current['active']!=true},title:current['active']==true?'Deactivate company':'Activate company');add('companies','delete',v:{'id':recId});if(current['logoUrl']!=null)native('GET','/companies/{id}/logo',v:{'id':recId},title:'View company logo');}break;
 case 'roles':if(f(src,'canRoles')){add('organization','update-role',v:{'id':recId});add('organization','delete-role',v:{'id':recId});}break;
 case 'people':if(section=='members'||section=='staffAccounts'){final u=r['userId'];final edit=(src['editableMembershipIds'] as List? ?? []).contains(r['id']);if(f(src,'canPeople')&&edit){add('organization','update-member',v:{'userId':u});add('organization','delete-member',v:{'userId':u});add('organization','add-scope',v:{'memberId':recId});}if(f(src,'canDelegate'))add('organization','grant-power',v:{'userId':u});}else if(section=='memberScopes'&&f(src,'canPeople')){add('organization','update-scope',v:{'id':recId});add('organization','remove-scope',v:{'id':recId});}else if(section=='grants'&&f(src,'canDelegate')){add('organization','update-power-grant',v:{'id':recId});add('organization','delete-power-grant',v:{'id':recId});add('organization','revoke-power',v:{'id':recId});}break;
 case 'accounts':case 'applications':if(r['status']=='Pending'){add('departments','review',v:{'id':recId,'approve':true},title:'Accept application');add('departments','review',v:{'id':recId,'approve':false},title:'Reject application');if(f(src,'canRouteRequests'))add('departments','route-request',v:{'id':recId});}else if(r['status']=='Approved'){native('GET','/departments/applications/{id}/confirmation',v:{'id':recId},title:'View confirmation');if(r['requestedRoleCode']==null)native('GET','/departments/applications/{id}/handoff',v:{'id':recId},title:'View temporary credential handoff');add('departments','mark-shared',v:{'id':recId});add('departments','retry-delivery',v:{'id':recId});}break;
 case 'departments':if(section=='departments'&&(src['editableDepartmentIds'] as List? ?? []).contains(recId)){add('departments','rename',v:{'id':recId});add('departments','delete',v:{'id':recId});add('departments','assign-member',v:{'departmentId':recId});}else if(section=='departmentMembers'){add('departments','update-member-department',v:{'id':recId});add('departments','remove-member',v:{'id':recId});}break;
 case 'hierarchy':if(section=='positions'){final v={'id':recId,'expectedUpdatedUtc':r['updatedUtc'],'parentId':r['parentPositionId']};add('hierarchy','update-position',v:v,title:'Edit position');add('hierarchy','delete-position',v:v,title:'Delete position');}else if(section=='departments')add('hierarchy','move-department',v:{'id':recId,'parentId':r['parentDepartmentId']});break;
 case 'territories':if(section=='zones'&&f(src,'canZone')){add('organization','update-zone',v:{'id':recId});add('organization','delete-zone',v:{'id':recId});}if(section=='links'&&f(src,'canDistrict'))add('organization','unlink-district',v:{'zoneId':r['zoneId'],'districtId':r['districtId']});if(section=='areas'&&f(src,'canArea')){add('organization','rename-area',v:{'id':recId},title:'Rename thana');add('organization','relink-thana-zone',v:{'id':recId});add('organization','delete-area',v:{'id':recId},title:'Remove thana');}if(section=='branches'&&f(src,'canBranch')){for(final ac in ['relink-branch-zone','change-branch-thana','update-branch','delete-branch'])add('organization',ac,v:{'id':recId});}break;
 case 'warehouses':if(f(src,'canWarehouse')){for(final ac in ['update-warehouse','relink-warehouse-zone','delete-warehouse'])add('inventory',ac,v:{'id':recId});}if(f(src,'canAssign'))add('inventory','assign-product',v:{'warehouseId':recId});break;
 case 'products':if(f(src,'canProduct')){add('inventory','update-product',v:{'id':recId});add('inventory','delete-product',v:{'id':recId});}if((src['productPhotoIds'] as List? ?? []).contains(recId)){native('GET','/inventory/products/{id}/image',v:{'id':recId},title:'View product image');if(f(src,'canProduct'))add('inventory','delete-product-image',v:{'id':recId});}if(f(src,'canAssign'))add('inventory','assign-product',v:{'productId':recId});break;
 case 'stock':if((src['adjustableInventoryIds'] as List? ?? []).contains(recId))add('inventory','adjust-stock',v:{'inventoryId':recId});if((src['unassignableInventoryIds'] as List? ?? []).contains(recId))add('inventory','unassign-product',v:{'id':recId});break;
 case 'clients':if(current['isArchived']==true||widget.archived)native('POST','/clients/{id}/restore',v:{'id':recId},title:'Restore client');else{native('PUT','/clients/{id}',v:{'id':recId},title:'Edit client');native('DELETE','/clients/{id}',v:{'id':recId},title:'Archive client');}break;
 case 'packages':final type=section=='packages'?'package':section=='parameters'?'parameter':'product';add('packages','update-$type',v:{'id':recId,if(type=='package')'Items':listOf(src,'items').where((x)=>x['packageId']==recId).toList()});add('packages','delete-$type',v:{'id':recId});break;
 case 'tasks':if(f(d,'canEditTask')){add('tasks','update',v:{'id':recId},title:'Edit task');add('tasks','delete',v:{'id':recId});}if(f(d,'canAssign')||f(d,'canMonitor'))add('tasks','assign',v:{'id':recId,'kind':f(d,'canAssign')?'Participant':'Monitor'});if(f(d,'canReport'))add('tasks','report',v:{'id':recId},title:'Submit report');if(f(d,'canSetStatus'))add('tasks','status',v:{'id':recId},title:'Update task status');if(f(d,'canAssignInstaller'))add('dispatches','assign',v:{'taskId':recId},title:'Assign installer');break;
 case 'dispatches':if(f(d,'canRespond')){add('dispatches','respond',v:{'id':recId,'decision':'Accept'},title:'Accept assignment');add('dispatches','respond',v:{'id':recId,'decision':'Reject'},title:'Reject assignment');}if(f(d,'canSchedule')){add('dispatches','schedule',v:{'id':recId,'scheduledInstallationDate':current['scheduledInstallationDate']??current['daOfferedInstallationDate']},title:'Confirm installation date');if(d['canRetrySms']==true||(d['canRetrySms']==null&&current['scheduledInstallationDate']!=null&&current['smsStatus']!='Sending'))add('dispatches','retry-sms',v:{'id':recId},title:'Retry completion verification');}if(f(d,'canAssignWorkers'))add('dispatches','assign-worker',v:{'id':recId});if(f(d,'canReport')&&current['scheduledInstallationDate']!=null)add('dispatches','progress',v:{'id':recId,'progress':'InProgress'},title:'Mark in progress');if(f(d,'canComment')||f(d,'canReport'))add('dispatches','report',v:{'id':recId},title:'Send work note');if(f(d,'canVerifyOtp')&&(d['canSubmitOtp']==true||(d['canSubmitOtp']==null&&['Sent','DemoReady'].contains(current['smsStatus']))))add('dispatches','verify-completion-otp',v:{'id':recId},title:'Verify completion OTP');break;
 case 'notifications':native('POST','/notifications/{id}/open',v:{'id':recId},title:'Open related record');if(current['isRead']!=true)native('POST','/notifications/{id}/read',v:{'id':recId},title:'Mark as read');native('DELETE','/notifications/{id}',v:{'id':recId},title:'Delete notification');break;
 }return result;}
 List<Widget> subrows(Map<String,dynamic> d,Map<String,dynamic> current){final out=<Widget>[];void group(String name,List<Map<String,dynamic>> items,List<ActionSpec> Function(Map<String,dynamic>) acts){if(items.isEmpty)return;out.addAll([const SizedBox(height:20),TideSection(title:name),const SizedBox(height:10)]);for(final x in items){final opts=acts(x);
 final dock=opts.isEmpty?null:TideActionDock(compact:true,title:heading(x),actions:opts.map((op)=>presentAction(widget.catalog,op,()=>run(op,d,current))).toList());
 if(name=='Reports'||name=='Work notes & timeline'){
  out.add(TideTimelineEntry(title:heading(x),description:(x['report']??x['body'])?.toString(),stamp:x['createdUtc']==null?null:prettyValue('createdUtc',x['createdUtc']),last:identical(x,items.last),actions:dock));
 }else{
  out.add(Padding(padding:const EdgeInsets.only(bottom:10),child:Column(children:[
    BusinessRecordCard(module:name=='Company members'||name=='Field team'||name=='Participants and monitors'?'people':name=='Package products'?'products':key,section:'items',data:displayRecord(x,{...merged(widget.source,d),'navigation':a.me['navigation']})),
    if(dock!=null)dock,
  ])));
 }
}}

 if(key=='companies'){group('Company members',rows(d['members']).map((x)=>{...obj(x['membership']),'email':x['email']}).toList(),(x)=>[if(a.superAdmin)...[cmd('companies','review-member',initial:{'id':id,'memberId':x['id'],'approve':true},title:'Approve'),cmd('companies','review-member',initial:{'id':id,'memberId':x['id'],'approve':false},title:'Reject'),cmd('companies','set-company-admin',initial:{'id':id,'memberId':x['id']},title:'Set company admin'),cmd('companies','revoke-member',initial:{'id':id,'memberId':x['id']},title:'Revoke'),cmd('companies','delete-member-link',initial:{'id':id,'memberId':x['id']},title:'Remove link')]]);}
 if(key=='tasks'){group('Participants and monitors',rows(d['participants']),(x)=>[if(f(d,'canChangeAssignment'))... [cmd('tasks','change-assignment',initial:{'id':id,'assignmentId':x['id'],'kind':x['kind']}),cmd('tasks','remove-assignment',initial:{'id':id,'assignmentId':x['id']})]]);group('Reports',rows(d['reports']),(x)=>[if(f(d,'canReport')&&x['authorUserId']==a.me['userId'])... [cmd('tasks','update-report',initial:{'id':id,'reportId':x['id'],'report':x['report']}),cmd('tasks','delete-report',initial:{'id':id,'reportId':x['id']})]]);group('Installer assignments',rows(d['dispatches']),(x)=>[]);for(final x in rows(d['dispatches']))out.add(TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>RecordPage(api:a,catalog:widget.catalog,module:modules.firstWhere((m)=>m.key=='dispatches'),section:'items',record:x,source:d,path:'/dispatches/${x['id']}',brand:widget.brand,archived:false))),child:CopyText('Open ${heading(x)} →')));}
 if(key=='dispatches'){group('Work notes & timeline',rows(d['messages']),(x)=>[]);group('Field team',rows(d['workers']),(x)=>[if(f(d,'canAssignWorkers'))cmd('dispatches','remove-worker',initial:{'id':id,'workerId':x['id']})]);}
 if(key=='packages'&&section=='packages')group('Package products',listOf(widget.source,'items').where((x)=>x['packageId']==id).toList(),(x)=>[]);
 return out;}
 @override Widget build(BuildContext c)=>PopScope(canPop:true,onPopInvokedWithResult:(_,__) {},child:Scaffold(appBar:AppBar(title:CopyText(widget.module.title),leading:BackButton(onPressed:()=>Navigator.pop(context,changed)),actions:[IconButton(tooltip:'Find a page',onPressed:()=>openWorkspaceSearch(context,a,widget.catalog,widget.brand),icon:const Icon(Icons.search_rounded)),IconButton(tooltip:'Refresh',onPressed:reload,icon:const Icon(Icons.refresh))]),body:FlowCanvas(brand:widget.brand,dark:Theme.of(c).brightness==Brightness.dark,child:FutureBuilder<Map<String,dynamic>>(future:future,builder:(c,s){if(s.connectionState==ConnectionState.waiting&&!s.hasData)return const TideLoading();if(s.hasError)return Center(child:Padding(padding:const EdgeInsets.all(20),child:TideNotice(s.error.toString(),title:'Unable to load record',error:true,retry:reload)));final d=s.data??{};final current=key=='companies'?obj(d['company']):key=='tasks'?obj(d['task']):key=='dispatches'?obj(d['dispatch']):{...r,...d};final record=current.isEmpty?r:current;final aa=actions(d,record);final available=aa.map((op)=>presentAction(widget.catalog,op,()=>run(op,d,record))).toList();if(key=='companies'&&a.superAdmin&&record['active']==true)available.insert(0,TideAction(title:'Open workspace',icon:Icons.business_outlined,onTap:()async{if(!await confirmAction(context,'Open company workspace?',message:'Subsequent operations will use the selected company scope.'))return;try{await a.selectWorkspace(record['id'] as int);if(mounted)Navigator.of(context).popUntil((route)=>route.isFirst);}catch(e){if(mounted)toast(context,e.toString());}}));return Column(children:[Expanded(child:ListView(padding:const EdgeInsets.all(17),children:[if(key=='companies')CompanyIdentityCard(api:a,data:record,key:ValueKey('detail-company-'+record['id'].toString()+'-'+identityHashCode(d).toString()),memberCount:rows(d['members']).length,onMore:available.isEmpty?null:()=>showTideActions(c,available,title:heading(record)))else BusinessRecordCard(module:key,section:section,data:displayRecord(record,{...merged(widget.source,d),'navigation':a.me['navigation']}),media:key=='products'&&record['id'] is int&&(widget.source['productPhotoIds'] as List? ?? []).contains(record['id'])?TideProductPhoto(api:a,id:record['id'] as int):null),const SizedBox(height:16),if(key=='dispatches')... [HeroCard(brand:widget.brand,title:'${record['progress']??record['status']??'Assignment'}',subtitle:d['canSeeCustomer']==true?'Authorized installation details':'Customer details hidden until accepted',tag:'INSTALLATION'),const SizedBox(height:12),if(d['smsConfigured']==false&&d['demoOtpEnabled']!=true)const Panel(child:CopyText('SMS completion is unavailable until the server is configured.'))],DetailPanel(data:displayRecord(record,{...merged(widget.source,d),'navigation':a.me['navigation']})),...subrows(d,record),const SizedBox(height:20)])),if(available.isNotEmpty)SafeArea(top:false,minimum:const EdgeInsets.fromLTRB(14,4,14,10),child:TideActionDock(title:heading(record),actions:available))]);}))));}
class OperationResult{final dynamic data;final bool changed;const OperationResult(this.data,this.changed);}
class Choice{final String value,text;const Choice(this.value,this.text);}
class OperationPage extends StatefulWidget{final Api api;final Operation operation;final String? title;final Map<String,dynamic> initial,source;const OperationPage({super.key,required this.api,required this.operation,this.title,this.initial=const{},this.source=const{}});@override State<OperationPage> createState()=>_OperationPageState();}
class _OperationPageState extends State<OperationPage>{final key=GlobalKey<FormState>();final controls=<String,TextEditingController>{};final uploads=<String,Upload>{};final selections=<String,Set<String>>{};final itemRows=<String,List<Map<String,TextEditingController>>>{};final referenceRows=<TextEditingController>[];bool locating=false;bool busy=false,finished=false,showSecret=false;String? error;dynamic result;Map<String,dynamic>? deletionPreview;bool previewBusy=false;String? emailStatus;Operation get op=>widget.operation;Map<String,dynamic> get src=>widget.source;
 @override void initState(){super.initState();for(final f in op.fields){final k=f['key'] as String;var v=caseValue(widget.initial,k)??f['default'];if(v==null&&norm(k)=='expectedupdatedutc')v=widget.initial['updatedUtc'];if(f['kind']=='items'){if(v==null&&norm(k)=='packageproducts'&&widget.initial['packageProductsJson'] is String){try{v=(jsonDecode(widget.initial['packageProductsJson']) as List).map((x)=>obj(x).map((k,v)=>MapEntry(k[0].toLowerCase()+k.substring(1),v))).toList();}catch(_){}}itemRows[k]=[];if(v is List){for(final row in rows(v))itemRows[k]!.add(itemControllers(row['productId'],row['quantity']));}continue;}if(f['kind']=='multi'){selections[k]=v is List?v.map((x)=>x.toString()).toSet():{};continue;}if(f['kind']=='file')continue;controls[k]=TextEditingController(text:v?.toString()??'');}
 if(singleTerritoryForm(op.path))restoreScopeAncestors();if(taskForm)syncTaskProducts(preserve:true);if(op.path.endsWith('/applications')&&op.isPublic){final refs=selections['ReferrerNames']??{};referenceRows.addAll(refs.map((v)=>TextEditingController(text:v)));if(referenceRows.isEmpty)referenceRows.add(TextEditingController());}
 if(op.method=='GET'&&op.fields.every((f)=>f['required']!=true||controls[f['key']]?.text.isNotEmpty==true))WidgetsBinding.instance.addPostFrameCallback((_)=>submit());}
 Map<String,TextEditingController> itemControllers(dynamic product,dynamic qty)=>{'ProductId':TextEditingController(text:product?.toString()??''),'Quantity':TextEditingController(text:qty?.toString()??'1')};
 @override void dispose(){for(final c in referenceRows)c.dispose();for(final c in controls.values)c.dispose();for(final list in itemRows.values){for(final row in list){for(final c in row.values)c.dispose();}}super.dispose();}
 String val(String k)=>controls.entries.where((e)=>norm(e.key)==norm(k)).map((e)=>e.value.text.trim()).firstOrNull??'';


 void restoreScopeAncestors(){
  TextEditingController? control(String k)=>controls.entries.where((e)=>norm(e.key)==k).map((e)=>e.value).firstOrNull;
  void fill(String k,dynamic v){if(v!=null&&control(k)!=null&&control(k)!.text.isEmpty)control(k)!.text=v.toString();}
  Map<String,dynamic>? find(String list,String id)=>listOf(src,list).where((r)=>r['id'].toString()==id&&id.isNotEmpty).firstOrNull;
  final branch=find('branches',val('branchId'));fill('areaid',branch?['areaId']);fill('districtid',branch?['districtId']);fill('zoneid',branch?['zoneId']);
  final thana=find('areas',val('areaId'));fill('districtid',thana?['districtId']);fill('zoneid',thana?['zoneId']);
  if(val('districtId').isNotEmpty&&val('zoneId').isEmpty){
   final link=listOf(src,'links').where((x)=>x['districtId'].toString()==val('districtId')).firstOrNull;fill('zoneid',link?['zoneId']);
  }
 }
 bool isChoiceField(String k)=>const ['zoneid','districtid','areaid','branchid','departmentid','userid','rolecode','requestedrolecode','powercode','warehouseid','productid','clientid','packageid','installercompanyid','packagenameid','bessid','inverterid','parentpositionid','parentid'].contains(norm(k));
 bool get taskForm=>op.group=='tasks'&&['create','update'].contains(op.action);
 List<Map<String,dynamic>> get taskProducts=>listOf(src,'items').where((x)=>x['packageId'].toString()==val('packageId')&&val('packageId').isNotEmpty).toList()..sort((a,b)=>(a['productName']??'').toString().compareTo((b['productName']??'').toString()));
 void syncTaskProducts({bool preserve=false}){
  final list=itemRows['packageProducts'];if(list==null)return;
  final previous={for(final row in list)row['ProductId']!.text:row['Quantity']!.text};
  for(final row in list){for(final c in row.values)c.dispose();}list.clear();
  for(final product in taskProducts){final id=product['productId'];list.add(itemControllers(id,preserve?previous[id.toString()]??1:1));}
 }
 bool hiddenField(Map<String,dynamic> f){
  final k=f['key'] as String;final n=norm(k);
  if(f['hidden']==true)return true;if(op.path=='/commands/packages/create-parameter'&&n=='kind')return true;
  if(n=='removefront'&&src['hasFront']!=true||n=='removeback'&&src['hasBack']!=true)return true;
  if(n=='confirmcompanywide'){
   final wasScoped=['zoneId','districtId','areaId','branchId'].any((x)=>caseValue(widget.initial,x)!=null);
   return !wasScoped||['zoneId','districtId','areaId','branchId'].any((x)=>val(x).isNotEmpty);
  }
  if(['id','assignmentid','reportid','memberid','workerid','taskid','expectedupdatedutc'].contains(n)&&caseValue(widget.initial,k)!=null)return true;
  if(n=='userid'&&['update-member','delete-member'].contains(op.action))return true;
  if(n=='inventoryid'&&caseValue(widget.initial,k)!=null)return true;if(n=='userid'&&op.path=='/commands/organization/grant-power'&&caseValue(widget.initial,k)!=null)return true;
  return false;
 }
 String fieldTitle(String k){
  final n=norm(k);
  if(taskForm)return switch(n){'title'=>'Task title','tasktype'=>'Task type (optional)','description'=>'Instructions','clientid'=>'Client from Client Portal','packageid'=>'Solar package (optional)',_=>label(k)};
  if(op.group=='clients'||op.path=='/clients'||op.path=='/clients/{id}')return switch(n){'name'=>'Customer name','mobile'=>'Mobile number (optional)','address'=>'Address (optional)','productinterest'=>'Product / service notes (optional)','gpslocationurl'=>'GPS location URL (optional)',_=>label(k)};
  return switch(n){'requestedrolecode'=>'Requested designation','primarycolor'=>'Primary brand color','accentcolor'=>'Accent color','referrernames'=>'References','initialquantity'=>'Initial total quantity','warehouseid' when op.path=='/commands/packages/create-product'=>'Receive into warehouse','unitprice'=>'Unit price (BDT)',_=>label(k)};
 }
 String? parityError(String k,String value){
  final n=norm(k);final v=value.trim();if(v.isEmpty)return null;
  if(taskForm&&n=='title'&&(v.length<3||v.length>180))return 'Enter 3–180 characters';
  if(taskForm&&n=='tasktype'&&v.length>140)return 'Maximum 140 characters';
  if(taskForm&&n=='description'&&(v.length<3||v.length>8000))return 'Enter 3–8000 characters';
  if(op.group=='tasks'&&n=='report'&&(v.length<3||v.length>4000))return 'Enter 3–4000 characters';
  if((op.path=='/clients'||op.path=='/clients/{id}')&&n=='name'&&(v.length<2||v.length>150))return 'Enter 2–150 characters';
  if((op.path=='/clients'||op.path=='/clients/{id}')&&n=='mobile'&&!RegExp(r'^(?:\+[1-9][0-9]{7,14}|0[0-9]{8,14}|[1-9][0-9]{7,14})$').hasMatch(v))return 'Enter a valid local or international mobile number';
  if(['address','productinterest'].contains(n)&&v.length>500)return 'Maximum 500 characters';
  if(n=='gpslocationurl'&&v.length>1024)return 'Maximum 1024 characters';
  if(n=='whatsapp'&&(op.isPublic||['departments','profile'].contains(op.group))&&!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(v))return 'Use a country code, e.g. +880';
  if(n=='password'&&['create-initial','applications'].contains(op.action)&&(value.length<6||value.length>128))return 'Enter 6–128 characters';
  if(op.group=='companies'){
   final max=<String,int>{'name':180,'slug':70,'description':1500,'contactemail':180,'phone':35,'website':300}[n];
   if(max!=null&&v.length>max)return 'Maximum '+max.toString()+' characters';
   if(n=='name'&&v.length<2)return 'Enter at least two characters';
   if(n=='slug'&&!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(v))return 'Use lowercase letters, numbers and hyphens';
  }
  if(n=='initialquantity'&&(int.tryParse(v)==null||int.parse(v)<0||int.parse(v)>1000000))return 'Enter a whole number from 0 to 1000000';
  if(n=='unitprice'&&(num.tryParse(v)==null||num.parse(v)<0||num.parse(v)>999999999999.99))return 'Enter a valid non-negative price';
  return null;
 }
 Widget taskClientSummary(){
  final selected=listOf(src,'clients').where((x)=>x['id'].toString()==val('clientId')).firstOrNull;
  if(selected==null)return TideNotice(listOf(src,'clients').isEmpty?'No active clients are available in your authorized territory. Create one in Client Portal or ask an authorized team member.':'Choose an existing client to continue.');
  final mobile=selected['mobile']?.toString()??'';final address=selected['address']?.toString()??'';
  return TideSurface(tinted:true,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Row(children:[TideAvatar(selected['name']?.toString()??'',size:44),const SizedBox(width:12),Expanded(child:CopyText(selected['name']?.toString()??'',style:Theme.of(context).textTheme.titleMedium))]),
   if(mobile.isNotEmpty)...[const SizedBox(height:10),TideFact(label:'Mobile number',value:mobile)],
   if(address.isNotEmpty)...[const SizedBox(height:10),TideMapLink(address:address,gps:selected['gpsLocationUrl']?.toString())],
   const SizedBox(height:10),const CopyText('Client name, phone and address come from Client Portal. Edit the client there to change them.'),
  ]));
 }
 Widget taskQuantityEditor(){
  if(val('packageId').isEmpty)return const SizedBox.shrink();
  final products=taskProducts;final list=itemRows['packageProducts']!;
  if(products.isEmpty||products.length!=list.length)return const TideNotice('No active products were returned for this package.',error:true);
  num amount=0;bool unpriced=false;
  for(var i=0;i<products.length;i++){final price=num.tryParse(products[i]['unitPrice'].toString());final quantity=int.tryParse(list[i]['Quantity']!.text);if(price==null||price<=0){unpriced=true;}else if(quantity!=null&&quantity>0){amount+=price*quantity;}}
  return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   const TideSection(title:'Products and quantities for this task',subtitle:'Only quantities can change. No stock is deducted here.'),
   const SizedBox(height:10),
   for(var i=0;i<products.length;i++)Padding(padding:const EdgeInsets.only(bottom:10),child:TideSurface(tinted:true,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    CopyText(products[i]['productName']?.toString()??'Product',style:Theme.of(context).textTheme.titleMedium),
    const SizedBox(height:6),CopyText([products[i]['unit'],if(products[i]['upc']!=null)'UPC '+products[i]['upc'].toString(),'BDT '+(products[i]['unitPrice']?.toString()??'—')].where((v)=>v!=null).join(' · ')),
    const SizedBox(height:12),
    TextFormField(key:ObjectKey(list[i]['Quantity']),controller:list[i]['Quantity'],keyboardType:TextInputType.number,
     inputFormatters:[FilteringTextInputFormatter.digitsOnly],decoration:InputDecoration(labelText:'Quantity ('+(products[i]['unit']?.toString()??'')+')'),
     onChanged:(_)=>setState((){}),validator:(v){final n=int.tryParse(v??'');return n==null||n<1||n>1000000?'Enter 1–1000000':null;}),
    const SizedBox(height:8),CopyText('Line total: BDT '+((num.tryParse(products[i]['unitPrice'].toString())??0)*(int.tryParse(list[i]['Quantity']!.text)??0)).toStringAsFixed(2)),
   ]))),
   if(unpriced)const TideNotice('Set a positive unit price for every selected package product before saving.',error:true),
   TideMetric(label:'Estimated package value',value:'BDT '+amount.toStringAsFixed(2),icon:Icons.payments_outlined),
  ]);
 }
 Widget referencesEditor()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  const TideSection(title:'References',subtitle:'At least one · up to 10 people'),
  for(var i=0;i<referenceRows.length;i++)Padding(padding:const EdgeInsets.only(top:10),child:TextFormField(key:ObjectKey(referenceRows[i]),controller:referenceRows[i],maxLength:120,decoration:InputDecoration(labelText:'Reference name',suffixIcon:IconButton(tooltip:'Remove reference',onPressed:busy||referenceRows.length<=1?null:(){setState(()=>referenceRows.removeAt(i).dispose());},icon:const Icon(Icons.remove_circle_outline))),validator:(v)=>(v??'').trim().length<2?'Enter at least two characters':null)),
  TextButton.icon(onPressed:busy||referenceRows.length>=10?null:()=>setState(()=>referenceRows.add(TextEditingController())),icon:const Icon(Icons.add),label:const CopyText('Add reference')),
 ]);

 bool get territoryDelete=>op.group=='organization'&&['delete-zone','unlink-district','delete-area','delete-branch'].contains(op.action);
 bool boolField(String k)=>['approve','active','confirmcompanywide','removefront','removeback'].contains(norm(k));
 bool secretField(String k)=>norm(k).contains('password')||norm(k)=='code'&&op.path.contains('verify-completion-otp');
 bool dateField(String k)=>norm(k).endsWith('date');
 bool numericField(String k)=>norm(k).endsWith('id')||['delta','unitprice','initialquantity','quantity'].contains(norm(k));
 bool locked(String k)=>['slug','invite','id','expectedupdatedutc','assignmentid','reportid','memberid','workerid','inventoryid'].contains(norm(k))&&caseValue(widget.initial,k)!=null||['active','approve','decision','companykind'].contains(norm(k))&&caseValue(widget.initial,k)!=null;
 List<Choice> options(String k){final n=norm(k);List<Map<String,dynamic>> data=[];String vk='id';switch(n){case 'zoneid':data=listOf(src,'zones');break;case 'districtid':data=listOf(src,'districts');if(controls.keys.any((x)=>norm(x)=='zoneid')&&val('zoneId').isEmpty)return [];if(val('zoneId').isNotEmpty&&op.action!='assign-district'){final ids=listOf(src,'links').where((x)=>x['zoneId'].toString()==val('zoneId')).map((x)=>x['districtId']).toSet();data=data.where((x)=>ids.contains(x['id'])).toList();}break;case 'areaid':if(controls.keys.any((x)=>norm(x)=='districtid')&&val('districtId').isEmpty)return [];data=listOf(src,'areas').where((x)=>(val('zoneId').isEmpty||x['zoneId'].toString()==val('zoneId'))&&(val('districtId').isEmpty||x['districtId'].toString()==val('districtId'))).toList();break;case 'branchid':if(controls.keys.any((x)=>norm(x)=='areaid')&&val('areaId').isEmpty)return [];data=listOf(src,'branches').where((x)=>(val('zoneId').isEmpty||x['zoneId'].toString()==val('zoneId'))&&(val('districtId').isEmpty||x['districtId'].toString()==val('districtId'))&&(val('areaId').isEmpty||x['areaId'].toString()==val('areaId'))).toList();break;case 'departmentid':data=listOf(src,'departments');break;case 'userid':if(op.action=='grant-power'){data=listOf(src,'delegationRecipients');break;}data=[...listOf(src,'candidates'),...listOf(src,'users'),...listOf(src,'people'),...listOf(src,'departmentUsers'),...listOf(src,'members'),...listOf(src,'delegationRecipients')];break;case 'memberid':data=listOf(src,'members');break;case 'rolecode':case 'requestedrolecode':data=listOf(src,'roles');if(op.action=='create-role-user')data=data.where((r)=>r['kind']=='Standard'&&r['active']!=false).toList();vk='code';break;case 'powercodes':case 'powercode':data=listOf(src,'availablePowers');vk='code';break;case 'warehouseid':data=[...listOf(src,'assignableWarehouses'),...listOf(src,'receiveWarehouses'),...listOf(src,'warehouses')];break;case 'productid':data=listOf(src,'products');if(data.isEmpty)data=listOf(src,'items');break;case 'clientid':data=listOf(src,'clients');break;case 'packageid':data=listOf(src,'packages');break;case 'installercompanyid':data=listOf(src,'installerCompanies');break;case 'packagenameid':case 'bessid':case 'inverterid':final wanted=n=='packagenameid'?'packagename':n=='bessid'?'bess':'inverter';data=listOf(src,'parameters').where((r)=>r['kind'].toString().toLowerCase().replaceAll(RegExp('[^a-z]'),'')==wanted).toList();break;case 'parentpositionid':case 'parentid':data=listOf(src,op.action=='move-department'?'departments':'positions');break;case 'kind':if(op.group=='organization'&&op.action=='create-role')return (src['assignableRoleKinds'] as List? ?? []).map((x)=>Choice(x.toString(),label(x.toString()))).toList();if(op.group=='tasks')return [if(src['canAssign']==true)const Choice('Participant','Participant'),if(src['canMonitor']==true)const Choice('Monitor','Monitoring member')];if(op.group=='packages')return const [Choice('PackageName','Package name'),Choice('Bess','BESS'),Choice('Inverter','Inverter')];break;case 'companykind':return const [Choice('DemandAggregator','Demand Aggregator'),Choice('Installer','Installer')];case 'status':if(op.group=='tasks')return const [Choice('Open','Open'),Choice('InProgress','In progress'),Choice('Completed','Completed')];break;case 'track':return const [Choice('General','General')];case 'decision':return const [Choice('Accept','Accept'),Choice('Reject','Reject')];case 'progress':return const [Choice('InProgress','In progress')];case 'side':return const [Choice('front','Front'),Choice('back','Back')];}
 final out=<String,Choice>{};for(final r in data){final v=n=='userid'?r['userId']??r['id']:n=='productid'?r['productId']??r['id']:r[vk];if(v==null)continue;final text=n=='clientid'?[heading(r),r['mobile']].where((x)=>x!=null&&x.toString().isNotEmpty).join(' · '):n=='packageid'?[r['packageName'],r['bess'],r['inverter']].where((x)=>x!=null&&x.toString().isNotEmpty).join(' · '):n=='parentpositionid'||n=='parentid'&&op.action!='move-department'?displayRole(r['roleCode'],src,name:r['roleName'])+' · '+(rows(src['people']).where((u)=>u['id']==r['userId']).firstOrNull?['fullName']?.toString()??'Open position'):r['label']?.toString()??heading(r);out[v.toString()]=Choice(v.toString(),text);}return out.values.toList();}
 Future<void> pickFile(String k)async{final result=await FilePicker.pickFiles(type:op.path.endsWith('import-products')?FileType.custom:FileType.image,allowedExtensions:op.path.endsWith('import-products')?['xlsx','csv']:null,withData:true);if(result==null||!mounted)return;if(result.files.length!=1)return;final file=result.files.single;if(file.bytes==null)return;final limit=op.group=='companies'?1000000:op.path.endsWith('import-products')?6291456:op.group=='profile'?2000000:4500000;if(file.size>limit){toast(context,'File exceeds the allowed upload size.');return;}setState(()=>uploads[k]=Upload(file.name,file.bytes!));}
 Widget selectField(String k,TextEditingController c,List<Choice> opts,bool required){
 final values={for(final x in opts)x.value:x.text};
 if(c.text.isNotEmpty&&!values.containsKey(c.text))values[c.text]='Current selection (unavailable)';
 return TideSelectField(key:ObjectKey(c),label:fieldTitle(k),value:c.text,options:values,required:required,enabled:!locked(k)&&!busy,onChanged:(v)=>setState((){c.text=v;final n=norm(k);final clear=n=='zoneid'?['districtid','areaid','branchid']:n=='districtid'?['areaid','branchid']:n=='areaid'?['branchid']: <String>[];for(final e in controls.entries.where((e)=>clear.contains(norm(e.key)))){if(!locked(e.key))e.value.clear();}if(n=='packageid'&&taskForm)syncTaskProducts();}));}
 Widget field(Map<String,dynamic> f){final k=f['key'] as String;final required=f['required']==true||(territoryDelete&&k=='confirmation')||(op.action=='respond'&&k=='note'&&val('decision')=='Reject');if(f['kind']=='file')return TideSurface(tinted:true,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[TideSetting(icon:Icons.cloud_upload_outlined,title:label(k),subtitle:uploads[k]?.name??'No file selected',onTap:busy?null:()=>pickFile(k)),if(uploads.containsKey(k))Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>setState(()=>uploads.remove(k)),child:const CopyText('Remove selection')))]));if(f['kind']=='multi'){if(norm(k)=='referrernames')return referencesEditor();final selected=selections[k]!;final choices=options(k);return Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CopyText(label(k),style:Theme.of(context).textTheme.titleMedium),if(choices.isNotEmpty)TideSetting(icon:Icons.checklist_rounded,title:'Choose '+label(k),subtitle:selected.length.toString()+' selected',onTap:busy?null:()async{final result=await showTideSheet<Set<String>>(context,title:label(k),subtitle:'Select the options you need',icon:Icons.checklist_rounded,content:(_)=>TideChoiceList(values:{for(final x in choices)x.value:x.text},selected:selected,multiple:true));if(result!=null&&mounted)setState(()=>selections[k]=result);})else if(norm(k)=='referrernames')TextFormField(initialValue:selected.join('\n'),maxLines:3,decoration:const InputDecoration(hintText:'One reference name per line'),onChanged:(v)=>selections[k]=v.split('\n').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toSet())else const CopyText('No delegable permissions returned by server.') ]));}
 if(f['kind']=='items'){if(taskForm&&norm(k)=='packageproducts')return taskQuantityEditor();final list=itemRows[k]!;List<Choice> choices=options('productId');final pkg=val('packageId');if(norm(k)=='packageproducts'&&pkg.isNotEmpty){final items=listOf(src,'items').where((r)=>r['packageId'].toString()==pkg).toList();choices=items.map((r)=>Choice('${r['productId']}',r['productName']?.toString()??'Product ${r['productId']}')).toList();}return Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CopyText(label(k),style:Theme.of(context).textTheme.titleMedium),if(norm(k)=='items')const CopyText('Select distinct products. Package quantity is fixed to one; task quantities can be changed.'),for(var i=0;i<list.length;i++)... [const SizedBox(height:10),selectField('ProductId',list[i]['ProductId']!,choices,true),if(norm(k)!='items')Padding(padding:const EdgeInsets.only(top:8),child:TextFormField(controller:list[i]['Quantity'],keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Quantity'),validator:(v)=>(int.tryParse(v??'')??0)<1?'Enter positive quantity':null)),TextButton.icon(onPressed:()=>setState((){final row=list.removeAt(i);for(final c in row.values)c.dispose();}),icon:const Icon(Icons.remove_circle_outline),label:const CopyText('Remove product'))],OutlinedButton.icon(onPressed:()=>setState(()=>list.add(itemControllers(null,1))),icon:const Icon(Icons.add),label:const CopyText('Add product'))]));}
 final c=controls[k]!;if(norm(k)=='gpslocationurl')return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 TextFormField(controller:c,readOnly:locked(k),keyboardType:TextInputType.url,maxLength:1024,
 decoration:InputDecoration(labelText:fieldTitle(k),hintText:'Paste a saved Maps link',prefixIcon:const Icon(Icons.location_on_outlined),
 suffixIcon:IconButton(tooltip:'Paste location link',onPressed:locked(k)||busy?null:()async{final clip=await Clipboard.getData('text/plain');if(mounted&&clip?.text!=null)c.text=clip!.text!.trim();},icon:const Icon(Icons.content_paste_rounded))),
 validator:(v)=>parityError(k,v??'')),
 OutlinedButton.icon(onPressed:locating||busy||locked(k)?null:()async{
  setState(()=>locating=true);
  try{
   final result=await const MethodChannel('idcolda/location').invokeMapMethod<String,dynamic>('currentLocation');
   final lat=result?['latitude'];final lon=result?['longitude'];
   if(!mounted)return;
   if(lat is! num||lon is! num||!lat.isFinite||!lon.isFinite||lat.abs()>90||lon.abs()>180)throw const FormatException('Invalid coordinates');
   c.text='https://www.google.com/maps?q='+lat.toStringAsFixed(6)+','+lon.toStringAsFixed(6);
   toast(context,'Current location captured. Save the form to store the link.');
  }on PlatformException catch(e){if(mounted)toast(context,e.message??'Location unavailable. Paste a Maps URL.');}
  catch(_){if(mounted)toast(context,'Location unavailable. Paste a Maps URL.');}
  finally{if(mounted)setState(()=>locating=false);}
 },icon:locating?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.my_location),label:CopyText(locating?'Requesting location…':'Use current location')),
 const CopyText('Permission is requested only when you tap Use current location. This is not continuous tracking.'),
 ValueListenableBuilder<TextEditingValue>(valueListenable:c,builder:(context,v,_)=>tideMapUri(gps:v.text)==null?const SizedBox.shrink():Padding(padding:const EdgeInsets.only(top:8),child:TideMapLink(gps:v.text)))
 ]);if(['primarycolor','accentcolor'].contains(norm(k)))return TideColorField(label:label(k),value:c.text,required:required,enabled:!locked(k)&&!busy,onChanged:(v)=>setState(()=>c.text=v));if(norm(k)=='email'&&op.path.contains('/public/companies/')&&op.path.endsWith('/applications'))return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[TextFormField(controller:c,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email address'),validator:(v)=>v==null||!v.contains('@')?'Enter a valid email':null,onChanged:(_)=>setState(()=>emailStatus=null)),TextButton(onPressed:()async{try{final d=obj(await widget.api.get('/public/companies/${val('slug')}/email-available',query:{'email':c.text.trim()},auth:false));if(mounted)setState(()=>emailStatus=d['available']==true?'Email is available':'Email is already in use or invalid');}catch(e){if(mounted)setState(()=>emailStatus=e.toString());}},child:const CopyText('Check email availability')),if(emailStatus!=null)CopyText(emailStatus!)]);if(boolField(k))return TideSetting(icon:Icons.toggle_on_outlined,title:label(k),trailing:Switch(value:c.text.toLowerCase()=='true',onChanged:locked(k)?null:(v)=>setState(()=>c.text=v.toString())));final opts=options(k);if(opts.isNotEmpty||isChoiceField(k))return selectField(k,c,opts,required);if(norm(k)=='expectedupdatedutc')return TextFormField(controller:c,readOnly:true,decoration:const InputDecoration(labelText:'Record version (server provided)'),validator:(v)=>v==null||v.isEmpty?'Reload this record':null);
 return TextFormField(controller:c,readOnly:locked(k)||dateField(k),onTap:dateField(k)?()async{final now=DateTime.now();final d=await showDatePicker(context:context,initialDate:DateTime.tryParse(c.text)??now,firstDate:DateTime(2000),lastDate:DateTime(2100));if(d!=null&&mounted)setState(()=>c.text=d.toIso8601String().split('T').first);}:null,obscureText:secretField(k)&&!showSecret,enableSuggestions:!secretField(k),autocorrect:!secretField(k),keyboardType:secretField(k)&&norm(k)=='code'?TextInputType.number:numericField(k)?const TextInputType.numberWithOptions(decimal:true,signed:true):norm(k).contains('email')?TextInputType.emailAddress:TextInputType.text,maxLines:!secretField(k)&&['description','report','body','note','address','notes','productinterest'].contains(norm(k))?3:1,decoration:InputDecoration(labelText:tr(context,fieldTitle(k))+(required?' *':''),suffixIcon:secretField(k)?IconButton(icon:Icon(showSecret?Icons.visibility_off:Icons.visibility),onPressed:()=>setState(()=>showSecret=!showSecret)):dateField(k)?const Icon(Icons.calendar_today_outlined):null),validator:(v){if(required&&(v==null||v.trim().isEmpty))return 'Required';if(v==null||v.isEmpty)return null;final parity=parityError(k,v);if(parity!=null)return parity;if(numericField(k)&&num.tryParse(v)==null)return 'Enter a valid number';if(norm(k)=='code'&&op.path.contains('verify-completion-otp')&&!RegExp(r'^\d{6}$').hasMatch(v))return 'Enter six digits';if(norm(k).contains('color')&&!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v))return 'Use #RRGGBB';if(norm(k)=='confirmpassword'&&v!=(controls.entries.where((e)=>norm(e.key)=='newpassword'||norm(e.key)=='password').map((e)=>e.value.text).firstOrNull??''))return 'Passwords do not match';return null;});}
 Future<void> previewDelete()async{setState((){previewBusy=true;error=null;});try{final kind=switch(op.action){'delete-zone'=>'zone','unlink-district'=>'district','delete-area'=>'thana',_=>'branch'};final v=obj(await widget.api.get('/organization/territory-delete-preview',query:{'kind':kind,'id':kind=='district'?val('districtId'):val('id'),if(kind=='district')'zoneId':val('zoneId')}));if(mounted)setState(()=>deletionPreview=v);}catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>previewBusy=false);}}
 Future<void> submit()async{if(busy||locating||finished||!(key.currentState?.validate()??true))return;if(taskForm&&(val('clientId').isEmpty||!listOf(src,'clients').any((x)=>x['id'].toString()==val('clientId')))){setState(()=>error='Choose an active registered client.');return;}if(taskForm&&val('packageId').isNotEmpty&&(!listOf(src,'packages').any((x)=>x['id'].toString()==val('packageId'))||taskProducts.isEmpty||taskProducts.length>50||taskProducts.any((p)=>(num.tryParse(p['unitPrice'].toString())??0)<=0))){setState(()=>error='Choose a valid package with priced products.');return;}if(op.path=='/commands/packages/create-product'&&(int.tryParse(val('InitialQuantity'))??0)>0&&val('WarehouseId').isEmpty){setState(()=>error='Select an authorized warehouse for initial stock.');return;}final data=<String,dynamic>{};final query=<String,dynamic>{};var path=op.path;for(final f in op.fields){final k=f['key'] as String;final kind=f['kind'];if(kind=='file'){if(f['required']==true&&!uploads.containsKey(k)){setState(()=>error='Select ${label(k)}.');return;}if(uploads[k]!=null)data[k]=uploads[k];continue;}if(kind=='multi'){final list=norm(k)=='referrernames'?referenceRows.map((c)=>c.text.trim()).toList():selections[k]!.toList();if(f['required']==true&&list.isEmpty){setState(()=>error='Select ${label(k)}.');return;}for(var i=0;i<list.length;i++)data['$k[$i]']=list[i];continue;}if(kind=='items'){final list=itemRows[k]!;if(f['required']==true&&list.isEmpty){setState(()=>error='Add at least one product.');return;}final ids=<String>{};for(var i=0;i<list.length;i++){final pid=list[i]['ProductId']!.text;if(pid.isEmpty||!ids.add(pid)){setState(()=>error='Choose distinct products.');return;}data['$k[$i].ProductId']=pid;data['$k[$i].Quantity']=norm(k)=='items'?'1':list[i]['Quantity']!.text;}continue;}
 var value=secretField(k)?controls[k]!.text:controls[k]!.text.trim();if(boolField(k)&&value.isEmpty)value='false';if(kind=='path'){if(value.isEmpty)return;path=path.replaceAll('{$k}',Uri.encodeComponent(value));continue;}if(value.isEmpty){if(op.mode=='raw'&&f['required']!=true)data[k]='';continue;}if(op.method=='GET')query[k]=value;else data[k]=op.mode=='raw'&&numericField(k)?num.tryParse(value)??value:value;}
 normalizeTerritoryPayload(op.path,data);if(op.action=='grant-power'&&['zoneId','districtId','areaId','branchId'].every((x)=>val(x).isEmpty)){final global=(src['globallyDelegablePowerCodes'] as List? ?? []).map((x)=>x.toString()).toSet();if((selections['powerCodes']??{}).any((x)=>!global.contains(x))){setState(()=>error='Select an authorized territory for the selected accessibility.');return;}}if(uploads.values.fold<int>(0,(n,u)=>n+u.bytes.length)>(op.group=='companies'?1900000:op.path.endsWith('import-products')?6100000:4800000)){setState(()=>error='Total upload size exceeds the supported limit.');return;}if(territoryDelete&&(deletionPreview==null||val('confirmation')!=deletionPreview!['name'])){setState(()=>error='Load the server impact preview and type the exact territory name.');return;}
 if(op.method!='GET'){setState(()=>busy=true);final confirmed=await confirmAction(context,widget.title??op.title,message:territoryDelete?'Remove only the relations shown in the verified server impact preview.':op.destructive?'This action may permanently modify access or remove live records. Continue only if intended.':'Submit this action to the live IDCOLDA system?');if(!mounted)return;if(!confirmed){setState(()=>busy=false);return;}}if(!mounted)return;setState((){busy=true;error=null;});try{final v=await widget.api.request(op.method,path,auth:!op.isPublic,mode:op.mode,data:data,query:query,binary:op.binary);if(!mounted)return;setState((){result=v;finished=true;});if(op.method!='GET'){for(final c in controls.entries.where((e)=>secretField(e.key)))c.value.clear();Navigator.pop(context,OperationResult(v,true));}}catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> saveBinary()async{final bytes=result as Uint8List;await FilePicker.saveFile(dialogTitle:'Save authorized download',fileName:op.path.endsWith('import-template')?'IDCOLDA-products-template.csv':'IDCOLDA-image.png',bytes:bytes);}
 Widget resultView(){if(result is Uint8List){if(op.path.endsWith('import-template'))return FilledButton.icon(onPressed:saveBinary,icon:const Icon(Icons.download),label:const CopyText('Save template'));return Column(children:[Image.memory(result as Uint8List,errorBuilder:(_,__,___)=>const CopyText('The returned file is not a supported image.')),if(!op.path.contains('/profile/photo/'))TextButton(onPressed:saveBinary,child:const CopyText('Save image'))]);}final d=obj(result);if(d.containsKey('temporaryPassword'))return Handoff(data:d,api:widget.api,initial:op.path.contains('/initial-accounts/'));if(op.path.endsWith('/confirmation'))return ApplicationConfirmation(data:d,api:widget.api);return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[DetailPanel(data:d),for(final e in d.entries.where((e)=>e.value is Map))... [const SizedBox(height:12),CopyText(label(e.key),style:Theme.of(context).textTheme.titleMedium),DetailPanel(data:obj(e.value))],for(final e in d.entries.where((e)=>e.value is List&&rows(e.value).isNotEmpty))... [CopyText(label(e.key),style:Theme.of(context).textTheme.titleMedium),...rows(e.value).map((x)=>DetailPanel(data:x))]]);}
 @override Widget build(BuildContext c){
  final title=widget.title??op.title;
  final done=finished&&op.method=='GET';
  return Scaffold(
    appBar:AppBar(title:CopyText(title),actions:[if(!done)IconButton(tooltip:'Cancel',onPressed:busy?null:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded))]),
    body:SafeArea(bottom:false,child:ListView(padding:const EdgeInsets.fromLTRB(17,12,17,24),children:[
      TideBanner(eyebrow:op.method=='GET'?'VIEW RECORD':'WORKSPACE ACTION',title:title,
        subtitle:op.method=='GET'?'Retrieve authorized information.':'Review the details before saving.',icon:actionIcon(op.path,op.method)),
      const SizedBox(height:16),
      if(op.destructive)...[const TideNotice('Review carefully. This changes your live workspace.',error:true),const SizedBox(height:14)],
      if(done)resultView()else Form(key:key,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        TideSurface(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const TideSection(title:'Details'),
          const SizedBox(height:6),
          if(op.path=='/commands/companies/edit'&&widget.initial['slug']!=null)...[const SizedBox(height:12),TideFact(label:'Permanent login URL identifier',value:widget.initial['slug'].toString())],
          for(final f in op.fields)if((!territoryDelete||f['key']!='confirmation')&&!hiddenField(f))...[Padding(padding:const EdgeInsets.only(top:16),child:field(f)),if(taskForm&&f['key']=='clientId')Padding(padding:const EdgeInsets.only(top:10),child:taskClientSummary())],
        ])),
        if(territoryDelete)...[
          const SizedBox(height:14),OutlinedButton(onPressed:previewBusy?null:previewDelete,child:const CopyText('Review server-calculated impact')),
          if(deletionPreview!=null)...[
            const SizedBox(height:12),DetailPanel(data:deletionPreview!),
            for(final x in rows(deletionPreview!['affected']))DetailPanel(data:x),
            Padding(padding:const EdgeInsets.only(top:12),child:field(op.fields.firstWhere((f)=>f['key']=='confirmation'))),
          ],
        ],
        if(error!=null)...[const SizedBox(height:14),TideNotice(error!,title:'Unable to submit',error:true)],
      ])),
    ])),
    bottomNavigationBar:done?null:SafeArea(top:false,minimum:const EdgeInsets.fromLTRB(14,8,14,12),child:
      TideSurface(padding:const EdgeInsets.all(9),child:Row(children:[
        IconButton(tooltip:'Cancel',onPressed:busy?null:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded)),
        const SizedBox(width:8),Expanded(child:FilledButton.icon(onPressed:busy||locating?null:submit,
          icon:busy?const SizedBox(width:19,height:19,child:CircularProgressIndicator(strokeWidth:2)):Icon(op.method=='GET'?Icons.arrow_downward_rounded:Icons.check_rounded),
          label:CopyText(op.method=='GET'?'Load':taskForm?(op.action=='create'?'Create task':'Save task'):'Review & submit'))),
      ]))),
  );
 }
}
class Handoff extends StatefulWidget{final Map<String,dynamic> data;final Api api;final bool initial;const Handoff({super.key,required this.data,required this.api,required this.initial});@override State<Handoff> createState()=>_HandoffState();}
class _HandoffState extends State<Handoff>{bool reveal=false,shared=false,busy=false;Future<void> mark()async{if(busy||shared||!await confirmAction(context,'Mark as manually shared?',message:'Only mark after sharing with the intended recipient. WhatsApp delivery cannot be verified.'))return;setState(()=>busy=true);try{await widget.api.request('POST',widget.initial?'/commands/departments/mark-initial-shared':'/commands/departments/mark-shared',mode:'urlencoded',data:{'id':widget.data[widget.initial?'userId':'requestId']});if(mounted)setState((){reveal=false;shared=true;});}catch(e){if(mounted)toast(context,e.toString());}finally{if(mounted)setState(()=>busy=false);}}@override Widget build(BuildContext c){final d=widget.data;if(shared)return const Panel(child:CopyText('Marked manually shared. The server handoff has been closed.'));return Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CopyText('Private credential handoff',style:Theme.of(c).textTheme.titleLarge),const CopyText('Only share credentials with the intended account holder. The handoff expires on the server.'),DetailPanel(data:d),TextButton(onPressed:()=>setState(()=>reveal=!reveal),child:CopyText(reveal?'Hide temporary password':'Reveal temporary password')),if(reveal)SelectableText('${d['temporaryPassword']}'),FilledButton.icon(onPressed:()async{if(!await confirmAction(c,'Open WhatsApp? ',message:'Confirm you are sharing only with the intended recipient.'))return;final phone=d['whatsApp']??d['whatsapp'];final digits=phone.toString().replaceAll(RegExp(r'\D'),'');if(digits.length<8)return;final u=Uri.https('wa.me','/$digits',{'text':'IDCOLDA account\nEmail: ${d['email']}\nTemporary password: ${d['temporaryPassword']}\nLogin: ${d['loginUrl']}'});await launchUrl(u,mode:LaunchMode.externalApplication);},icon:const Icon(Icons.chat_outlined),label:const CopyText('Open WhatsApp')),OutlinedButton(onPressed:busy?null:mark,child:const CopyText('Mark as manually shared'))]));}}
class ApplicationConfirmation extends StatefulWidget{final Map<String,dynamic> data;final Api api;const ApplicationConfirmation({super.key,required this.data,required this.api});@override State<ApplicationConfirmation> createState()=>_ApplicationConfirmationState();}
class _ApplicationConfirmationState extends State<ApplicationConfirmation>{bool busy=false,shared=false;@override Widget build(BuildContext c){final d=obj(widget.data['application']);return Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CopyText('Approved account confirmation',style:Theme.of(c).textTheme.titleLarge),DetailPanel(data:d),CopyText('Login: ${widget.data['companyLoginUrl']??''}'),FilledButton.icon(onPressed:()async{final phone=(d['whatsApp']??d['whatsapp']??'').toString().replaceAll(RegExp(r'\D'),'');if(phone.length<8)return;await launchUrl(Uri.https('wa.me','/$phone',{'text':'Your IDCOLDA company application has been approved. Sign in with your registered email and password: ${widget.data['companyLoginUrl']}'}),mode:LaunchMode.externalApplication);},icon:const Icon(Icons.chat_outlined),label:const CopyText('Open WhatsApp confirmation')),OutlinedButton(onPressed:busy||shared?null:()async{if(!await confirmAction(c,'Mark as manually shared?'))return;setState(()=>busy=true);try{await widget.api.request('POST','/commands/departments/mark-shared',mode:'urlencoded',data:{'id':d['id']});if(mounted)setState(()=>shared=true);}catch(e){if(mounted)toast(c,e.toString());}finally{if(mounted)setState(()=>busy=false);}},child:CopyText(shared?'Marked as shared':'Mark manually shared'))]));}}
class PublicApplication extends StatefulWidget{final Api api;final Catalog catalog;final Brand brand;final String invite;const PublicApplication({super.key,required this.api,required this.catalog,required this.brand,required this.invite});@override State<PublicApplication> createState()=>_PublicApplicationState();}
class _PublicApplicationState extends State<PublicApplication>{late Future<dynamic> data=widget.api.get('/public/companies/${widget.brand.slug}/applications',query:{'invite':widget.invite},auth:false);@override Widget build(BuildContext c)=>FutureBuilder(future:data,builder:(c,s){if(s.hasError)return Scaffold(appBar:AppBar(title:const CopyText('Application invitation')),body:Center(child:Padding(padding:const EdgeInsets.all(20),child:CopyText(s.error.toString()))));if(!s.hasData)return Scaffold(appBar:AppBar(title:const CopyText('Application invitation')),body:const Center(child:CircularProgressIndicator()));return OperationPage(api:widget.api,operation:widget.catalog.op('POST','/public/companies/{slug}/applications'),title:'Apply for access',initial:{'slug':widget.brand.slug,'Invite':widget.invite},source:obj(s.data));});}

