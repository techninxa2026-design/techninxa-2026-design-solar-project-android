import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'api.dart';
import 'copy.dart';
import 'tide_cards.dart';
import 'record_presentation.dart';
import 'tide_interactions.dart';
import 'tide_editorial.dart';

class HierarchyDrag{
 final String kind;final Map<String,dynamic> row;
 const HierarchyDrag(this.kind,this.row);
}
class HierarchyChange{
 final String action,summary;final Map<String,dynamic> payload;
 const HierarchyChange(this.action,this.summary,this.payload);
}
HierarchyChange? hierarchyChange(Map<String,dynamic> source,HierarchyDrag from,String kind,Map<String,dynamic>? to){
 final p=from.row;final id=p['id'];final targetId=to?['id'];
 String role(Map<String,dynamic> x)=>displayRole(x['roleCode'],source);
 String name(Map<String,dynamic> x)=>(x['name']??x['fullName']??'Unavailable').toString();
 bool circular(String list,String parent){
  final byId={for(final x in rows(source[list]))x['id']:x};final seen=<dynamic>{};dynamic next=targetId;
  while(next!=null){if(next==id||!seen.add(next))return true;next=byId[next]?[parent];}return false;
 }
 if(from.kind=='position'&&(kind=='position'||kind=='root-position')){
  if(p['updatedUtc']==null||circular('positions','parentPositionId')||p['parentPositionId']==targetId)return null;
  return HierarchyChange('move-position','Move '+role(p)+' under '+(to==null?'company root':role(to)),{'id':id,'parentId':targetId??'','departmentId':p['departmentId']??'','expectedUpdatedUtc':p['updatedUtc']});
 }
 if(from.kind=='department'&&(kind=='department'||kind=='root-department')){
  if(circular('departments','parentDepartmentId')||p['parentDepartmentId']==targetId)return null;
  return HierarchyChange('move-department','Move '+name(p)+' under '+(to==null?'company root':name(to)),{'id':id,'parentId':targetId??''});
 }
 if(kind=='position'&&to!=null&&to['updatedUtc']!=null){
  if(from.kind=='person'&&id!=null&&to['userId']!=id)return HierarchyChange('assign-person','Assign '+name(p)+' to '+role(to),{'id':targetId,'userId':id,'expectedUpdatedUtc':to['updatedUtc']});
  if(from.kind=='role'&&p['code']!=null&&to['roleCode']!=p['code'])return HierarchyChange('change-position-role','Change '+role(to)+' to '+name(p),{'id':targetId,'roleCode':p['code'],'expectedUpdatedUtc':to['updatedUtc']});
 }
 if(from.kind=='position'&&kind=='department'&&to!=null&&p['updatedUtc']!=null&&p['departmentId']!=targetId)return HierarchyChange('move-position','Transfer '+role(p)+' to '+name(to),{'id':id,'parentId':p['parentPositionId']??'','departmentId':targetId,'expectedUpdatedUtc':p['updatedUtc']});
 return null;
}
class HierarchyBoard extends StatefulWidget{
 final Map<String,dynamic> data;final bool busy;final ValueChanged<HierarchyChange> onChange;
 final void Function(Map<String,dynamic>,String) onEdit;final VoidCallback onCreate;
 const HierarchyBoard({super.key,required this.data,required this.busy,required this.onChange,required this.onEdit,required this.onCreate});
 @override State<HierarchyBoard> createState()=>_HierarchyBoardState();
}
/// Readable reporting directory by default; visual editing is an explicit mode.
class _HierarchyBoardState extends State<HierarchyBoard>{
 bool departments=false,chart=false;
 final collapsed=<dynamic>{};String query='';
 Map<String,dynamic> get d=>widget.data;
 List<Map<String,dynamic>> get positions=>rows(d['positions']);
 List<Map<String,dynamic>> get depts=>rows(d['departments']);
 String role(Map<String,dynamic> p)=>displayRole(p['roleCode'],d);
 String employee(Map<String,dynamic> p)=>p['userId']==null?'Open position':rows(d['people']).where((x)=>x['id']==p['userId']).firstOrNull?['fullName']?.toString()??'Employee unavailable';
 String name(Map<String,dynamic> p)=>departments?(p['name']??'Department').toString():role(p);
 String department(Map<String,dynamic> p)=>p['departmentId']==null?'Company-wide':depts.where((x)=>x['id']==p['departmentId']).firstOrNull?['name']?.toString()??'Department unavailable';
 Future<void> guide(Map<String,dynamic> p)async{
  final kind=departments?'department':'position';
  final candidates=<HierarchyChange>[];
  void add(HierarchyDrag from,String kind,Map<String,dynamic>? to){final change=hierarchyChange(d,from,kind,to);if(change!=null)candidates.add(change);}
  add(HierarchyDrag(kind,p),'root-'+kind,null);
  for(final target in departments?depts:positions){add(HierarchyDrag(kind,p),kind,target);}
  if(!departments){
   for(final person in rows(d['people'])){add(HierarchyDrag('person',person),'position',p);}
   for(final role in rows(d['roles'])){add(HierarchyDrag('role',role),'position',p);}
   for(final target in depts){add(HierarchyDrag('position',p),'department',target);}
  }
  final chosen=await showTideSheet<HierarchyChange>(context,title:name(p),subtitle:'Choose a reporting or assignment change',icon:Icons.account_tree_outlined,content:(c)=>_HierarchyChoices(changes:candidates));
  if(chosen!=null&&mounted&&!widget.busy)widget.onChange(chosen);
 }
 Widget entry(Map<String,dynamic> p,int depth,int children){
  final t=Theme.of(context);final kind=departments?'department':'position';final id=p['id'];final isClosed=collapsed.contains(id);
  final card=DragTarget<HierarchyDrag>(onWillAcceptWithDetails:(x)=>!widget.busy&&hierarchyChange(d,x.data,kind,p)!=null,onAcceptWithDetails:(x){final change=hierarchyChange(d,x.data,kind,p);if(change!=null)widget.onChange(change);},builder:(c,active,rejected)=>TideSurface(tinted:active.isNotEmpty,padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    TideGlyph(departments?Icons.apartment_outlined:Icons.badge_outlined,size:42),const SizedBox(width:10),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     CopyText(name(p),style:t.textTheme.titleMedium),const SizedBox(height:4),
     CopyText(departments?'Department':employee(p),style:t.textTheme.bodyMedium),
     if(!departments)CopyText(department(p),style:t.textTheme.bodySmall),
    ])),
    if(children>0)IconButton(tooltip:isClosed?'Expand reports':'Collapse reports',onPressed:()=>setState(()=>isClosed?collapsed.remove(id):collapsed.add(id)),icon:Icon(isClosed?Icons.expand_more:Icons.expand_less)),
   ]),
   if(children>0)Padding(padding:const EdgeInsets.only(top:8),child:CopyText(children.toString()+' direct reports',style:t.textTheme.labelMedium)),
   const SizedBox(height:8),const Divider(height:1),const SizedBox(height:6),
   Wrap(spacing:8,runSpacing:4,children:[
    TextButton.icon(onPressed:widget.busy?null:()=>widget.onEdit(p,kind),icon:const Icon(Icons.edit_outlined,size:18),label:const CopyText('Edit details')),
    FilledButton.tonalIcon(onPressed:widget.busy?null:()=>guide(p),icon:const Icon(Icons.swap_horiz_rounded,size:19),label:const CopyText('Change reporting')),
   ]),
  ])));
  return Padding(padding:EdgeInsets.only(left:math.min(depth,3)*8.0,bottom:10),child:LongPressDraggable<HierarchyDrag>(
   data:HierarchyDrag(kind,p),maxSimultaneousDrags:widget.busy?0:1,feedback:Material(color:t.colorScheme.primary,borderRadius:BorderRadius.circular(16),child:Padding(padding:const EdgeInsets.all(15),child:Text(name(p),style:TextStyle(color:t.colorScheme.onPrimary)))),child:card));
 }
 @override Widget build(BuildContext c){
  final t=Theme.of(c);final records=departments?depts:positions;final parent=departments?'parentDepartmentId':'parentPositionId';
  final ids=records.map((x)=>x['id']).toSet();final seen=<dynamic>{};final entries=<Widget>[];
  void hide(Map<String,dynamic> p){if(!seen.add(p['id']))return;for(final x in records.where((x)=>x[parent]==p['id'])){hide(x);}}
  void visit(Map<String,dynamic> p,int depth){
   if(!seen.add(p['id']))return;
   final children=records.where((x)=>x[parent]==p['id']&&x['id']!=p['id']).toList();
   if(query.isEmpty||[name(p),if(!departments)employee(p),if(!departments)department(p)].join(' ').toLowerCase().contains(query))entries.add(entry(p,depth,children.length));
   for(final x in children){if(query.isNotEmpty||!collapsed.contains(p['id'])){visit(x,depth+1);}else{hide(x);}}
  }
  for(final p in records.where((x)=>!ids.contains(x[parent])||x[parent]==x['id'])){visit(p,0);}
  for(final p in records.where((x)=>!seen.contains(x['id']))){visit(p,0);}
  return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   Padding(padding:const EdgeInsets.fromLTRB(4,0,4,8),child:Row(children:[
    Expanded(child:CopyText(departments?'Departments':'Reporting structure',style:t.textTheme.titleLarge)),
    IconButton(tooltip:chart?'List view':'Visual editor',onPressed:()=>setState(()=>chart=!chart),icon:Icon(chart?Icons.view_list_rounded:Icons.account_tree_outlined)),
   ])),
   Wrap(spacing:8,runSpacing:4,children:[
    ChoiceChip(label:const CopyText('Positions'),selected:!departments,onSelected:(_)=>setState((){departments=false;collapsed.clear();query='';})),
    ChoiceChip(label:const CopyText('Departments'),selected:departments,onSelected:(_)=>setState((){departments=true;collapsed.clear();query='';})),
    if(!departments)TextButton.icon(onPressed:widget.busy?null:widget.onCreate,icon:const Icon(Icons.add),label:const CopyText('Add position')),
   ]),
   const SizedBox(height:8),
   if(widget.busy)const LinearProgressIndicator(),
   Expanded(child:chart?_HierarchyGraph(key:ValueKey(departments),data:d,busy:widget.busy,onChange:widget.onChange,onEdit:widget.onEdit,onCreate:widget.onCreate,departments:departments):ListView(children:[
    TideSurface(tinted:true,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Row(children:[const TideGlyph(Icons.admin_panel_settings_outlined,size:44),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CopyText(d['companyAdministrator']?.toString()??'Company administrator',style:t.textTheme.titleMedium),const CopyText('Company administrator')]))]),
     const SizedBox(height:12),Wrap(spacing:16,runSpacing:6,children:[CopyText(positions.length.toString()+' positions'),CopyText(depts.length.toString()+' departments')]),
     const SizedBox(height:10),OutlinedButton.icon(onPressed:()=>setState(()=>chart=true),icon:const Icon(Icons.account_tree_outlined),label:const CopyText('Open visual editor')),
    ])),
    const SizedBox(height:12),TextField(key:ValueKey(departments),onChanged:(v)=>setState(()=>query=v.trim().toLowerCase()),decoration:const InputDecoration(hintText:'Find a role or employee',prefixIcon:Icon(Icons.search_rounded))),
    const SizedBox(height:14),if(entries.isEmpty)const TideEmpty(message:'No matching positions or departments.'),...entries,
   ])),
  ]);
 }
}
class _HierarchyChoices extends StatefulWidget{
 final List<HierarchyChange> changes;const _HierarchyChoices({required this.changes});
 @override State<_HierarchyChoices> createState()=>_HierarchyChoicesState();
}
class _HierarchyChoicesState extends State<_HierarchyChoices>{
 String query='';
 @override Widget build(BuildContext c){
  final matches=widget.changes.where((x)=>x.summary.toLowerCase().contains(query.toLowerCase())).toList();
  return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   TextField(onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(hintText:'Search people, roles or destinations',prefixIcon:Icon(Icons.search))),
   const SizedBox(height:10),
   if(matches.isEmpty)const TideEmpty(message:'No available changes.'),
   for(final x in matches)Padding(padding:const EdgeInsets.only(bottom:8),child:TideSurface(onTap:()=>Navigator.pop(c,x),padding:const EdgeInsets.all(12),child:Row(children:[const Icon(Icons.swap_horiz_rounded),const SizedBox(width:10),Expanded(child:CopyText(x.summary)),const Icon(Icons.chevron_right)]))),
  ]);
 }
}
class _HierarchyGraph extends StatefulWidget{
 final Map<String,dynamic> data;final bool busy;final ValueChanged<HierarchyChange> onChange;final void Function(Map<String,dynamic>,String) onEdit;final VoidCallback onCreate;final bool departments;
 const _HierarchyGraph({super.key,required this.data,required this.busy,required this.onChange,required this.onEdit,required this.onCreate,required this.departments});
 @override State<_HierarchyGraph> createState()=>_HierarchyGraphState();
}
class _HierarchyGraphState extends State<_HierarchyGraph>{
 bool get departments=>widget.departments;String search='';String tray='person';final transform=TransformationController();
 @override void dispose(){transform.dispose();super.dispose();}
 Map<String,dynamic> get d=>widget.data;
 List<Map<String,dynamic>> get positions=>rows(d['positions']);
 List<Map<String,dynamic>> get depts=>rows(d['departments']);
 String role(Map<String,dynamic> p)=>displayRole(p['roleCode'],d);
 String person(Map<String,dynamic> p)=>p['userId']==null?'Open position':rows(d['people']).where((u)=>u['id']==p['userId']).firstOrNull?['fullName']?.toString()??'Employee unavailable';
 String dept(Map<String,dynamic> p)=>p['departmentId']==null?'Company-wide':depts.where((x)=>x['id']==p['departmentId']).firstOrNull?['name']?.toString()??'Department unavailable';
 String title(String kind,Map<String,dynamic> p)=>kind=='position'?role(p):(p['name']??p['fullName']??'Unavailable').toString();
 void zoom(double delta){final scale=(transform.value.getMaxScaleOnAxis()+delta).clamp(.45,1.6).toDouble();transform.value=Matrix4.diagonal3Values(scale,scale,1);}
 Widget feedback(String text)=>Material(color:Colors.transparent,child:Container(width:210,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Theme.of(context).colorScheme.primary,borderRadius:BorderRadius.circular(18)),child:Text(text,style:TextStyle(color:Theme.of(context).colorScheme.onPrimary,fontWeight:FontWeight.bold))));
 Widget drag(String kind,Map<String,dynamic> p,Widget child)=>LongPressDraggable<HierarchyDrag>(data:HierarchyDrag(kind,p),maxSimultaneousDrags:widget.busy?0:1,feedback:feedback(title(kind,p)),childWhenDragging:Opacity(opacity:.4,child:child),child:child);
 Widget target(String kind,Map<String,dynamic>? p,Widget Function(bool) child)=>DragTarget<HierarchyDrag>(
  onWillAcceptWithDetails:(x)=>!widget.busy&&hierarchyChange(d,x.data,kind,p)!=null,
  onAcceptWithDetails:(x){final change=hierarchyChange(d,x.data,kind,p);if(change!=null)widget.onChange(change);},
  builder:(c,candidates,rejected)=>child(candidates.isNotEmpty));
 Widget node(String kind,Map<String,dynamic> p){
  final t=Theme.of(context);final name=title(kind,p);
  final sub=kind=='position'?person(p):positions.where((x)=>x['departmentId']==p['id']).length.toString()+' positions';
  final matches=search.isEmpty||[name,sub,if(kind=='position')dept(p)].join(' ').toLowerCase().contains(search);
  return target(kind,p,(highlight){
   final card=Material(color:highlight?t.colorScheme.primaryContainer:t.colorScheme.surface,borderRadius:BorderRadius.circular(19),child:InkWell(
    onTap:widget.busy?null:()=>widget.onEdit(p,kind),borderRadius:BorderRadius.circular(19),child:Container(
    padding:const EdgeInsets.all(12),decoration:BoxDecoration(border:Border.all(color:highlight?t.colorScheme.primary:t.colorScheme.outline,width:highlight?3:1),borderRadius:BorderRadius.circular(19)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Row(children:[Icon(kind=='position'?Icons.badge_outlined:Icons.account_tree_outlined,color:t.colorScheme.primary,size:22),const Spacer(),const Icon(Icons.drag_indicator_rounded,size:22)]),
     const SizedBox(height:7),CopyText(name,style:t.textTheme.titleSmall,maxLines:2,overflow:TextOverflow.ellipsis),
     const SizedBox(height:5),CopyText(sub,style:t.textTheme.bodySmall,maxLines:2,overflow:TextOverflow.ellipsis),
     if(kind=='position')CopyText(dept(p),style:t.textTheme.labelSmall,maxLines:1,overflow:TextOverflow.ellipsis),
    ]))));
   return drag(kind,p,Opacity(opacity:matches||highlight?1:.38,child:card));
  });
 }
 Widget roster(String label,String kind,List<Map<String,dynamic>> records){
  return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   CopyText(label,style:Theme.of(context).textTheme.titleSmall),const SizedBox(height:6),
   if(records.isEmpty)const CopyText('No available items')else SizedBox(height:76,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:records.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(c,i){
    final p=records[i];
    final chip=TideSurface(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(kind=='person'?Icons.person_outline:kind=='role'?Icons.badge_outlined:Icons.apartment_outlined,size:20),const SizedBox(width:8),ConstrainedBox(constraints:const BoxConstraints(maxWidth:170),child:CopyText(title(kind,p),maxLines:2,overflow:TextOverflow.ellipsis)),const SizedBox(width:6),const Icon(Icons.drag_indicator,size:19)]));
    return Center(child:kind=='department'?target(kind,p,(highlight)=>Container(decoration:BoxDecoration(border:Border.all(color:highlight?Theme.of(c).colorScheme.primary:Colors.transparent,width:2),borderRadius:BorderRadius.circular(20)),child:chip)):drag(kind,p,chip));
   })),
  ]);
 }
 @override Widget build(BuildContext c){
  final kind=departments?'department':'position';final records=departments?depts:positions;
  final scale=MediaQuery.textScalerOf(c).scale(14)/14;
  final graph=HierarchyLayout(records,departments?'parentDepartmentId':'parentPositionId',nodeW:math.max(220.0,220*scale),nodeH:math.max(166.0,166*scale));
  final t=Theme.of(c);
  final keyboard=MediaQuery.viewInsetsOf(c).bottom>0;
  return LayoutBuilder(builder:(c,bounds){
   if(bounds.maxHeight<180)return const Center(child:CopyText('Close the keyboard to edit the chart.'));
   return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    if(!keyboard)Padding(padding:const EdgeInsets.only(bottom:8),child:CopyText('Hold a card to move it. Pinch to zoom.',style:t.textTheme.bodySmall)),
    if(!keyboard)...[
     Row(children:[Expanded(child:CopyText(departments?'Departments':'Positions',style:t.textTheme.titleSmall,maxLines:1,overflow:TextOverflow.ellipsis)),IconButton(tooltip:'Zoom out',onPressed:()=>zoom(-.15),icon:const Icon(Icons.remove)),IconButton(tooltip:'Reset zoom',onPressed:()=>transform.value=Matrix4.identity(),icon:const Icon(Icons.fit_screen_outlined)),IconButton(tooltip:'Zoom in',onPressed:()=>zoom(.15),icon:const Icon(Icons.add))]),
     target('root-'+kind,null,(highlight)=>AnimatedContainer(duration:const Duration(milliseconds:120),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:highlight?t.colorScheme.primaryContainer:t.colorScheme.surface,border:Border.all(color:t.colorScheme.primary,width:highlight?3:1),borderRadius:BorderRadius.circular(17)),child:const Row(children:[Icon(Icons.account_tree_outlined),SizedBox(width:10),Expanded(child:CopyText('Drop here to make top-level'))]))),
     const SizedBox(height:8),
    ],
    if(widget.busy)const LinearProgressIndicator(),
    Expanded(child:records.isEmpty?const Center(child:TideEmpty(message:'No positions or departments configured.')):Container(
     clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:t.colorScheme.surfaceContainerLowest,border:Border.all(color:t.colorScheme.outlineVariant),borderRadius:BorderRadius.circular(20)),
     child:InteractiveViewer(transformationController:transform,constrained:false,boundaryMargin:const EdgeInsets.all(100),minScale:.45,maxScale:1.6,
      child:SizedBox(width:graph.width,height:graph.height,child:Stack(children:[
       Positioned.fill(child:CustomPaint(painter:_Links(graph,t.colorScheme.primary.withValues(alpha:.5)))),
       for(final p in records)if(graph.rects[p['id']]!=null)Positioned.fromRect(rect:graph.rects[p['id']]!,child:node(kind,p)),
      ]))),
    )),
    if(!departments&&!keyboard&&bounds.maxHeight>260)...[
     const SizedBox(height:8),
     ConstrainedBox(constraints:BoxConstraints(maxHeight:bounds.maxHeight*.32),child:SingleChildScrollView(child:TideSurface(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
       for(final x in const [('person','Employees'),('role','Roles'),('department','Departments')])Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:CopyText(x.$2),selected:tray==x.$1,onSelected:(_)=>setState(()=>tray=x.$1))),
      ])),
      roster(tray=='person'?'Hold employee to assign':tray=='role'?'Hold role to assign':'Drop position here to transfer',tray,tray=='person'?rows(d['people']):tray=='role'?rows(d['roles']):depts),
     ])))),
    ],
   ]);
  });
 }
}

class HierarchyLayout{
 final Map<dynamic,Rect> rects={};final List<(dynamic,dynamic)> edges=[];
 late final double width,height;
 HierarchyLayout(List<Map<String,dynamic>> records,String parent,{required double nodeW,required double nodeH}){
  final byId={for(final p in records)p['id']:p};final children=<dynamic,List<dynamic>>{};
  for(final p in records){(children[p[parent]]??=[]).add(p['id']);}
  final visited=<dynamic>{};double cursor=18;int deepest=0;
  double place(dynamic id,int depth){
   if(!visited.add(id))return cursor;
   deepest=math.max(deepest,depth);final xs=<double>[];
   for(final child in children[id]??[]){if(!visited.contains(child)){xs.add(place(child,depth+1));edges.add((id,child));}}
   final double x;if(xs.isEmpty){x=cursor;cursor+=nodeW+28;}else{x=(xs.first+xs.last)/2;}
   rects[id]=Rect.fromLTWH(x,18+depth*(nodeH+46),nodeW,nodeH);return x;
  }
  for(final p in records){if(!byId.containsKey(p[parent])||p[parent]==p['id'])place(p['id'],0);}
  for(final p in records){if(!visited.contains(p['id']))place(p['id'],0);}
  width=math.max(nodeW+36,cursor);height=math.max(nodeH+36,36+(deepest+1)*nodeH+deepest*46);
 }
}
class _Links extends CustomPainter{
 final HierarchyLayout graph;final Color color;const _Links(this.graph,this.color);
 @override void paint(Canvas canvas,Size size){
  final pen=Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=2;
  for(final e in graph.edges){final a=graph.rects[e.$1]!,b=graph.rects[e.$2]!;final start=a.bottomCenter,end=b.topCenter,mid=(start.dy+end.dy)/2;
   canvas.drawPath(Path()..moveTo(start.dx,start.dy)..lineTo(start.dx,mid)..lineTo(end.dx,mid)..lineTo(end.dx,end.dy),pen);}
 }
 @override bool shouldRepaint(covariant _Links old)=>old.graph!=graph||old.color!=color;
}
