import 'package:flutter/material.dart';
import 'api.dart';
import 'catalog.dart';
import 'copy.dart';
import 'tide_cards.dart';
import 'tide_interactions.dart';

class WorkspaceDestination{
 final String title,module,group,description;final String? power,focus;
 const WorkspaceDestination(this.title,this.module,this.group,{this.description='',this.power,this.focus});
}
const navigationModules={
 'role.create':'roles','people.assign':'people','zone.create':'territories','district.assign':'territories',
 'area.create':'territories','branch.create':'territories','warehouse.create':'warehouses','product.create':'products',
 'stock.assign':'stock','store.manage':'stock','task.create':'tasks','task.assign':'tasks',
 'task.monitor.assign':'tasks','task.report':'tasks','account.create':'accounts','department.create':'departments',
 'hierarchy.manage':'hierarchy','client.create':'clients','package.manage':'packages',
};
List<WorkspaceDestination> workspaceDestinations(Api api,{Map<String,dynamic> organization=const{}}){
 if(!api.approved)return [];
 final rights=api.powers;final workspace=api.me['workspace']!=null;
 final out=<WorkspaceDestination>[];
 if(workspace&&!api.superAdmin)out.add(WorkspaceDestination(api.role=='DA'?'Demand Aggregator dashboard':'Installer dashboard','home','WORKSPACE'));
 final manage=workspace&&(rights.any((p)=>['role.create','people.assign','zone.create','district.assign','area.create','branch.create'].contains(p))||organization['canDelegate']==true&&rights.isNotEmpty);
 if(manage){
  out.add(const WorkspaceDestination('Operations overview','overview','WORKSPACE'));
  if(organization['canDelegate']==true)out.add(const WorkspaceDestination('Delegate Accessibility','people','WORKSPACE',focus:'grants'));
 }
 if(workspace){
  final nav=rows(api.me['navigation']);
  // The MVC auth response contains the same OpsPowerPages metadata as the sidebar.
  for(final page in nav){
   final code=page['code']?.toString();final module=navigationModules[code];
   if(code==null||module==null||!rights.contains(code))continue;
   out.add(WorkspaceDestination(page['title']?.toString()??module,module,page['group']?.toString()??'WORKSPACE',description:page['description']?.toString()??'',power:code));
  }
  if(rights.contains('account.create'))out.add(const WorkspaceDestination('Application Forms','applications','ACCOUNT APPLICATIONS'));
  if(rights.contains('department.create'))out.add(const WorkspaceDestination('Assign managers & employees','departments','DEPARTMENT TEAM',focus:'departmentMembers'));
  if(api.me['canViewSales']==true)out.add(const WorkspaceDestination('Sales Records','sales','SALES'));
 }
 if(api.superAdmin)out.add(const WorkspaceDestination('Demand Aggregator & Installer workspaces','companies','SUPERADMIN'));
 final assigned=api.me['hasAssignedTasks']==true;
 if(workspace&&(assigned||rights.any((p)=>['task.assign','task.create','task.report'].contains(p))))out.add(const WorkspaceDestination('Installer assignments & responses','dispatches','CROSS-COMPANY TASKS'));
 if(workspace&&assigned&&!rights.any((p)=>['task.create','task.assign','task.monitor.assign','task.report'].contains(p)))out.add(const WorkspaceDestination('Assigned Tasks','tasks','MY WORK'));
 out.addAll(const [WorkspaceDestination('Notifications','notifications','MY ACCOUNT'),WorkspaceDestination('My profile','profile','MY ACCOUNT')]);
 return out;
}
List<WorkspaceDestination> matchPages(List<WorkspaceDestination> pages,String query,{String Function(String)? translate}){
 final q=query.trim().toLowerCase();
 return pages.where((p)=>p.title.toLowerCase().contains(q)||(translate?.call(p.title).toLowerCase().contains(q)??false)).take(20).toList();
}
Future<WorkspaceDestination?> findWorkspacePage(BuildContext context,Api api){
 final scope=api.me['workspace'];
 final user=api.me['userId'];
 final lookup=()async{
  if(scope==null||!api.approved)return <String,dynamic>{};
  try{return obj(await api.get('/organization'));}catch(_){return <String,dynamic>{};}
 }();
 return showTideSheet<WorkspaceDestination>(context,title:'Find a page',subtitle:'Search the pages you can access',icon:Icons.search_rounded,content:(_)=>FutureBuilder<Map<String,dynamic>>(future:lookup,builder:(c,s){
  if(api.me['userId']!=user||!identical(api.me['workspace'],scope))return const TideEmpty(message:'Workspace changed. Reopen search.');
  return WorkspaceSearchResults(pages:workspaceDestinations(api,organization:s.data??{}));
 }));
}
class WorkspaceSearchResults extends StatefulWidget{
 final List<WorkspaceDestination> pages;
 const WorkspaceSearchResults({super.key,required this.pages});
 @override State<WorkspaceSearchResults> createState()=>_WorkspaceSearchResultsState();
}
class _WorkspaceSearchResultsState extends State<WorkspaceSearchResults>{
 String query='';
 @override Widget build(BuildContext c){
  final results=matchPages(widget.pages,query,translate:(x)=>tr(c,x));String? group;
  return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   TextField(autofocus:true,textInputAction:TextInputAction.search,decoration:InputDecoration(hintText:tr(c,'Search the pages you can access'),prefixIcon:const Icon(Icons.search_rounded)),onChanged:(v)=>setState(()=>query=v),onSubmitted:(_){if(results.length==1)Navigator.pop(c,results.single);}),
   const SizedBox(height:14),
   if(results.isEmpty)const TideEmpty(message:'No matching pages.'),
   for(final item in results)...[
    if(group!=item.group)...[Padding(padding:const EdgeInsets.only(top:10,bottom:7),child:CopyText(item.group,style:Theme.of(c).textTheme.labelMedium)),],
    Padding(padding:const EdgeInsets.only(bottom:7),child:TideSurface(onTap:()=>Navigator.pop(c,item),padding:const EdgeInsets.all(12),child:Row(children:[
     const TideGlyph(Icons.arrow_outward_rounded,size:36),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CopyText(item.title,style:Theme.of(c).textTheme.titleSmall),if(item.description.isNotEmpty)CopyText(item.description,style:Theme.of(c).textTheme.bodySmall)])),
    ]))),
    // A zero-size widget lets group headings follow the server's page order.
    _groupMarker(()=>group=item.group),
   ],
   const SizedBox(height:8),const CopyText('Select a result to open that page.'),
  ]);
 }
 Widget _groupMarker(VoidCallback setGroup){setGroup();return const SizedBox.shrink();}
}
