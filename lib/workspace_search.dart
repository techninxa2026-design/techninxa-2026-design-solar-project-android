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
 if(api.superAdmin){out.addAll(const [WorkspaceDestination('Company directory','companies','PLATFORM ADMINISTRATION',description:'Manage companies, Demand Aggregator & Installer workspaces'),WorkspaceDestination('Register company','register-company','PLATFORM ADMINISTRATION',description:'Add a Demand Aggregator or Installer'),WorkspaceDestination('Open workspace','choose-workspace','PLATFORM ADMINISTRATION',description:'Select an active company')]);}
 final assigned=api.me['hasAssignedTasks']==true;
 if(workspace&&(assigned||rights.any((p)=>['task.assign','task.create','task.report'].contains(p))))out.add(const WorkspaceDestination('Installer assignments & responses','dispatches','CROSS-COMPANY TASKS'));
 if(workspace&&assigned&&!rights.any((p)=>['task.create','task.assign','task.monitor.assign','task.report'].contains(p)))out.add(const WorkspaceDestination('Assigned Tasks','tasks','MY WORK'));
 out.addAll(const [WorkspaceDestination('Notifications','notifications','MY ACCOUNT'),WorkspaceDestination('My profile','profile','MY ACCOUNT')]);
 return out;
}
List<WorkspaceDestination> matchPages(List<WorkspaceDestination> pages,String query,{String Function(String)? translate}){
 final q=query.trim().toLowerCase();
 return pages.where((p)=>p.title.toLowerCase().contains(q)||p.description.toLowerCase().contains(q)||(translate?.call(p.title).toLowerCase().contains(q)??false)).take(20).toList();
}
Future<WorkspaceDestination?> findWorkspacePage(BuildContext context,Api api){
 final scope=api.me['workspace'];
 final user=api.me['userId'];
 final lookup=()async{
  if(scope==null||!api.approved)return <String,dynamic>{};
  try{return obj(await api.get('/organization'));}catch(_){return <String,dynamic>{};}
 }();
 return Navigator.of(context).push<WorkspaceDestination>(MaterialPageRoute(fullscreenDialog:true,builder:(c)=>Scaffold(
  appBar:AppBar(title:const CopyText('Find a feature'),leading:IconButton(tooltip:'Close',icon:const Icon(Icons.close_rounded),onPressed:()=>Navigator.pop(c))),
  body:SafeArea(child:FutureBuilder<Map<String,dynamic>>(future:lookup,builder:(c,s){
   if(api.me['userId']!=user||!identical(api.me['workspace'],scope))return const Center(child:TideEmpty(message:'Workspace changed. Reopen search.'));
   return WorkspaceSearchResults(pages:workspaceDestinations(api,organization:s.data??{}));
  })),
 )));
}
class FeatureSearchBar extends StatelessWidget{
 final VoidCallback onTap;const FeatureSearchBar({super.key,required this.onTap});
 @override Widget build(BuildContext c){
  final s=Theme.of(c).colorScheme;
  return Semantics(button:true,label:tr(c,'Find a feature'),child:Material(color:s.surfaceContainerHighest,borderRadius:BorderRadius.circular(20),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(20),child:Container(height:54,padding:const EdgeInsets.fromLTRB(7,5,12,5),decoration:BoxDecoration(border:Border.all(color:s.outline),borderRadius:BorderRadius.circular(20)),child:Row(children:[
   Container(width:42,height:42,decoration:BoxDecoration(color:s.primary,borderRadius:BorderRadius.circular(14)),child:Icon(Icons.search_rounded,color:s.onPrimary,size:24)),
   const SizedBox(width:12),Expanded(child:CopyText('Find a feature',style:Theme.of(c).textTheme.titleSmall,maxLines:1,overflow:TextOverflow.ellipsis)),
   Icon(Icons.arrow_forward_rounded,color:s.primary,size:20),
  ])))));
 }
}
class WorkspaceSearchResults extends StatefulWidget{
 final List<WorkspaceDestination> pages;
 const WorkspaceSearchResults({super.key,required this.pages});
 @override State<WorkspaceSearchResults> createState()=>_WorkspaceSearchResultsState();
}
class _WorkspaceSearchResultsState extends State<WorkspaceSearchResults>{
 final controller=TextEditingController();String query='';
 @override void dispose(){controller.dispose();super.dispose();}
 IconData iconFor(String module)=>switch(module){
  'companies'||'register-company'||'choose-workspace'=>Icons.apartment_rounded,
  'people'||'roles'||'accounts'||'applications'=>Icons.groups_outlined,
  'hierarchy'||'departments'=>Icons.account_tree_outlined,
  'clients'=>Icons.contact_phone_outlined,'tasks'||'dispatches'=>Icons.assignment_outlined,
  'warehouses'||'stock'||'products'||'packages'=>Icons.inventory_2_outlined,
  'notifications'=>Icons.notifications_outlined,'profile'=>Icons.person_outline,
  'sales'=>Icons.insights_outlined,_=>Icons.widgets_outlined,
 };
 @override Widget build(BuildContext c){
  final t=Theme.of(c);final results=matchPages(widget.pages,query,translate:(x)=>tr(c,x));
  final grouped=<String,List<WorkspaceDestination>>{};
  for(final item in results){(grouped[item.group]??=[]).add(item);}
  return Padding(padding:const EdgeInsets.fromLTRB(16,8,16,0),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   TextField(controller:controller,autofocus:true,textInputAction:TextInputAction.search,decoration:InputDecoration(hintText:tr(c,'Search features you can access'),prefixIcon:const Icon(Icons.search_rounded),suffixIcon:query.isEmpty?null:IconButton(tooltip:'Clear search',onPressed:(){controller.clear();setState(()=>query='');},icon:const Icon(Icons.close))),onChanged:(v)=>setState(()=>query=v),onSubmitted:(_){if(results.length==1)Navigator.pop(c,results.single);}),
   const SizedBox(height:12),CopyText(query.trim().isEmpty?'Available features':results.length.toString()+' matching features',style:t.textTheme.titleMedium),
   const SizedBox(height:8),Expanded(child:ListView(key:const ValueKey('feature-results'),children:[
    if(results.isEmpty)const TideEmpty(message:'No matching features. Try a different word.'),
    for(final group in grouped.entries)...[
     Padding(padding:const EdgeInsets.only(top:10,bottom:8),child:CopyText(group.key,style:t.textTheme.labelMedium?.copyWith(color:t.colorScheme.primary,fontWeight:FontWeight.w800))),
     for(final item in group.value)Padding(padding:const EdgeInsets.only(bottom:8),child:TideSurface(onTap:()=>Navigator.pop(c,item),padding:const EdgeInsets.all(12),child:Row(children:[
      TideGlyph(iconFor(item.module),size:43),const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CopyText(item.title,style:t.textTheme.titleSmall),if(item.description.isNotEmpty)...[const SizedBox(height:3),CopyText(item.description,style:t.textTheme.bodySmall,maxLines:2,overflow:TextOverflow.ellipsis)]])),
      const SizedBox(width:6),Icon(Icons.chevron_right_rounded,color:t.colorScheme.primary),
     ]))),
    ],
   ])),
  ]));
 }
}
