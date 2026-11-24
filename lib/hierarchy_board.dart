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
 final void Function(Map<String,dynamic>?,String)? onOpenEditor;final bool initialDepartments;final Object? initialFocusId;
 const HierarchyBoard({super.key,required this.data,required this.busy,required this.onChange,required this.onEdit,required this.onCreate,this.onOpenEditor,this.initialDepartments=false,this.initialFocusId});
 @override State<HierarchyBoard> createState()=>_HierarchyBoardState();
}
/// Readable reporting directory by default; visual editing is an explicit mode.
class _HierarchyBoardState extends State<HierarchyBoard>{
 late bool departments=widget.initialDepartments;bool chart=true;Object? focusId;
 @override void initState(){super.initState();focusId=widget.initialFocusId;}
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
  final t=Theme.of(context);final kind=departments?'department':'position';final id=p['id'];final isClosed=collapsed.contains(id);final parentId=p[departments?'parentDepartmentId':'parentPositionId'];final parent=(departments?depts:positions).where((x)=>x['id']==parentId).firstOrNull;
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
   const SizedBox(height:10),Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:tideTint(context,t.colorScheme.primary,.07),borderRadius:BorderRadius.circular(12)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.subdirectory_arrow_right_rounded,size:19,color:t.colorScheme.primary),const SizedBox(width:7),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const CopyText('Reports to'),CopyText(parent!=null?name(parent):parentId==null?'Company administrator':'Manager outside visible scope',style:t.textTheme.titleSmall)]))])),
   if(children>0)Padding(padding:const EdgeInsets.only(top:8),child:CopyText(children.toString()+(departments?' child departments':' direct reports'),style:t.textTheme.labelMedium)),
   const SizedBox(height:8),const Divider(height:1),const SizedBox(height:6),
   Wrap(spacing:8,runSpacing:4,children:[
    TextButton.icon(onPressed:widget.busy?null:()=>widget.onEdit(p,kind),icon:const Icon(Icons.edit_outlined,size:18),label:const CopyText('Edit details')),
    FilledButton.tonalIcon(onPressed:widget.busy?null:()=>guide(p),icon:const Icon(Icons.swap_horiz_rounded,size:19),label:CopyText(departments?'Change reporting':'Manage position')),
   ]),
  ])));
  return Padding(padding:EdgeInsets.only(left:math.min(depth,3)*8.0,bottom:10),child:LongPressDraggable<HierarchyDrag>(
   data:HierarchyDrag(kind,p),maxSimultaneousDrags:widget.busy?0:1,feedback:Material(color:t.colorScheme.primary,borderRadius:BorderRadius.circular(16),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:230),child:Padding(padding:const EdgeInsets.all(15),child:Text(name(p),style:TextStyle(color:t.colorScheme.onPrimary))))),child:card));
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
   LayoutBuilder(builder:(c,bounds){
    final s=t.colorScheme;
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     if(bounds.maxWidth>=300)Container(height:54,margin:const EdgeInsets.only(bottom:6),decoration:BoxDecoration(gradient:LinearGradient(colors:[s.primary.withValues(alpha:.14),s.surface.withValues(alpha:.4)]),borderRadius:BorderRadius.circular(18)),child:Stack(children:[
      Positioned(right:0,top:0,bottom:0,child:IgnorePointer(child:Opacity(opacity:.7,child:Image.asset('assets/solar_network.png',width:80,fit:BoxFit.contain)))),
      Padding(padding:const EdgeInsets.fromLTRB(9,5,80,5),child:Row(children:[
       Container(width:40,height:40,decoration:BoxDecoration(color:s.primary,borderRadius:BorderRadius.circular(12)),child:Icon(Icons.account_tree_rounded,color:s.onPrimary,size:23)),
       const SizedBox(width:9),Expanded(child:FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
        CopyText('Organization Structure',style:t.textTheme.titleMedium),CopyText('Manage your company’s hierarchy',style:t.textTheme.bodySmall),
       ]))),
      ])),
     ])),
     Row(children:[
      Expanded(child:_HierarchySegment(label:'Positions',icon:Icons.account_tree_outlined,selected:!departments,onTap:()=>setState((){departments=false;focusId=null;collapsed.clear();query='';}))),
      const SizedBox(width:5),
      Expanded(child:_HierarchySegment(label:'Departments',icon:Icons.layers_outlined,selected:departments,onTap:()=>setState((){departments=true;focusId=null;collapsed.clear();query='';}))),
      IconButton(tooltip:chart?'List view':'Visual editor',onPressed:()=>setState(()=>chart=!chart),icon:Icon(chart?Icons.view_list_rounded:Icons.account_tree_outlined)),
     ]),
     Row(children:[
      if(widget.onOpenEditor!=null)Expanded(child:TextButton.icon(onPressed:widget.busy?null:()=>widget.onOpenEditor!(null,departments?'department':'position'),icon:const Icon(Icons.open_in_full_rounded,size:18),label:const CopyText('Edit hierarchy'))),
      if(!departments)Expanded(child:TextButton.icon(onPressed:widget.busy?null:widget.onCreate,icon:const Icon(Icons.add_rounded,size:18),label:const CopyText('Add position'))),
     ]),
    ]);
   }),
   if(widget.busy)const LinearProgressIndicator(),
   Expanded(child:chart?_HierarchyGraph(key:ValueKey(departments),data:d,busy:widget.busy,onChange:widget.onChange,onEdit:widget.onOpenEditor==null?widget.onEdit:(row,kind)=>widget.onOpenEditor!(row,kind),onCreate:widget.onCreate,departments:departments,initialFocusId:focusId):ListView(children:[
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
/// A wide, near-full-height editing workspace. It owns the fresh chart
/// snapshot so confirmed mutations remain visible without closing the sheet.
Future<void> showHierarchyEditor(
 BuildContext context,{
 required Map<String,dynamic> data,
 required Future<Map<String,dynamic>> Function() refresh,
 required Future<void> Function(HierarchyChange) onChange,
 required Future<void> Function(Map<String,dynamic>,String,Map<String,dynamic>) onEdit,
 required Future<void> Function(Map<String,dynamic>) onCreate,
 bool initialDepartments=false,Object? initialFocusId,
})=>showModalBottomSheet<void>(
 context:context,isScrollControlled:true,useSafeArea:true,
 enableDrag:false,isDismissible:false,backgroundColor:Colors.transparent,
 constraints:BoxConstraints(maxWidth:MediaQuery.sizeOf(context).width),
 builder:(c)=>FractionallySizedBox(heightFactor:.97,child:_HierarchyEditorSheet(
  data:data,refresh:refresh,onChange:onChange,onEdit:onEdit,onCreate:onCreate,
  initialDepartments:initialDepartments,initialFocusId:initialFocusId,
 )),
);

class _HierarchyEditorSheet extends StatefulWidget{
 final Map<String,dynamic> data;
 final Future<Map<String,dynamic>> Function() refresh;
 final Future<void> Function(HierarchyChange) onChange;
 final Future<void> Function(Map<String,dynamic>,String,Map<String,dynamic>) onEdit;
 final Future<void> Function(Map<String,dynamic>) onCreate;
 final bool initialDepartments;final Object? initialFocusId;
 const _HierarchyEditorSheet({required this.data,required this.refresh,required this.onChange,required this.onEdit,required this.onCreate,required this.initialDepartments,this.initialFocusId});
 @override State<_HierarchyEditorSheet> createState()=>_HierarchyEditorSheetState();
}
class _HierarchyEditorSheetState extends State<_HierarchyEditorSheet>{
 late Map<String,dynamic> data=widget.data;
 bool busy=false;String? failure;
 Future<void> run(Future<void> Function() action)async{
  if(busy)return;
  setState((){busy=true;failure=null;});
  try{
   await action();
   if(!mounted)return;
   final latest=await widget.refresh();
   if(mounted)setState(()=>data=latest);
  }catch(e){if(mounted)setState(()=>failure='Unable to refresh the hierarchy. Retry before making another change.');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext c){
  final t=Theme.of(c);final color=t.appBarTheme.backgroundColor??t.colorScheme.primary;
  return PopScope(canPop:!busy,child:Material(
   key:const ValueKey('hierarchy-editor-sheet'),
   color:t.scaffoldBackgroundColor,borderRadius:const BorderRadius.vertical(top:Radius.circular(24)),clipBehavior:Clip.antiAlias,
   child:SafeArea(top:false,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    ColoredBox(color:color,child:Padding(padding:const EdgeInsets.fromLTRB(16,12,8,12),child:Row(children:[
     const Icon(Icons.account_tree_outlined,color:Colors.white,size:28),const SizedBox(width:12),
     const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      CopyText('Hierarchy editor',style:TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w800)),
      CopyText('Drag positions or tap to edit',style:TextStyle(color:Colors.white,fontSize:12)),
     ])),
     IconButton(tooltip:'Close hierarchy editor',onPressed:busy?null:()=>Navigator.pop(c),color:Colors.white,icon:const Icon(Icons.close_rounded)),
    ]))),
    if(failure!=null)Padding(padding:const EdgeInsets.all(8),child:Row(children:[
     Expanded(child:CopyText(failure!,style:t.textTheme.bodySmall?.copyWith(color:t.colorScheme.error))),
     TextButton(onPressed:busy?null:()=>run(()async{}),child:const CopyText('Retry')),
    ])),
    Expanded(child:Padding(padding:const EdgeInsets.fromLTRB(8,8,8,4),child:HierarchyBoard(
     data:data,busy:busy||failure!=null,initialDepartments:widget.initialDepartments,initialFocusId:widget.initialFocusId,
     onChange:(change)=>run(()=>widget.onChange(change)),
     onEdit:(row,kind)=>run(()=>widget.onEdit(row,kind,data)),
     onCreate:()=>run(()=>widget.onCreate(data)),
    ))),
   ])),
  ));
 }
}
class _HierarchyChoices extends StatefulWidget{
 final List<HierarchyChange> changes;const _HierarchyChoices({required this.changes});
 @override State<_HierarchyChoices> createState()=>_HierarchyChoicesState();
}
class _HierarchyChoicesState extends State<_HierarchyChoices>{
 String query='';
 String category(HierarchyChange x)=>switch(x.action){'assign-person'=>'Assign employee','change-position-role'=>'Change role','move-department'=>'Change department reporting','move-position' when x.summary.startsWith('Transfer')=>'Transfer department',_=>'Change reporting manager'};
 @override Widget build(BuildContext c){
  final matches=widget.changes.where((x)=>x.summary.toLowerCase().contains(query.toLowerCase())).toList();
  final groups=<String,List<HierarchyChange>>{};for(final x in matches){(groups[category(x)]??=[]).add(x);}
  return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   TextField(onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(hintText:'Search people, roles or destinations',prefixIcon:Icon(Icons.search))),
   const SizedBox(height:10),
   if(matches.isEmpty)const TideEmpty(message:'No available changes.'),
   for(final group in groups.entries)...[const SizedBox(height:8),TideSection(title:group.key),const SizedBox(height:8),for(final x in group.value)Padding(padding:const EdgeInsets.only(bottom:8),child:TideSurface(onTap:()=>Navigator.pop(c,x),padding:const EdgeInsets.all(12),child:Row(children:[const Icon(Icons.swap_horiz_rounded),const SizedBox(width:10),Expanded(child:CopyText(x.summary)),const Icon(Icons.chevron_right)])))],
  ]);
 }
}
class _HierarchyGraph extends StatefulWidget{
 final Map<String,dynamic> data;final bool busy;final ValueChanged<HierarchyChange> onChange;final void Function(Map<String,dynamic>,String) onEdit;final VoidCallback onCreate;final bool departments;final Object? initialFocusId;
 const _HierarchyGraph({super.key,required this.data,required this.busy,required this.onChange,required this.onEdit,required this.onCreate,required this.departments,this.initialFocusId});
 @override State<_HierarchyGraph> createState()=>_HierarchyGraphState();
}
class _HierarchyGraphState extends State<_HierarchyGraph>{
 bool get departments=>widget.departments;String search='';String tray='person';final transform=TransformationController();Size? viewport;bool initialized=false;bool dragging=false;bool trayExpanded=true;HierarchyDrag? picked;final canvasKey=GlobalKey();
 @override void dispose(){transform.dispose();super.dispose();}
 @override void didUpdateWidget(covariant _HierarchyGraph oldWidget){super.didUpdateWidget(oldWidget);if(!identical(oldWidget.data,widget.data))picked=null;}
 Map<String,dynamic> get d=>widget.data;
 List<Map<String,dynamic>> get positions=>rows(d['positions']);
 List<Map<String,dynamic>> get depts=>rows(d['departments']);
 String role(Map<String,dynamic> p)=>displayRole(p['roleCode'],d);
 String person(Map<String,dynamic> p)=>p['userId']==null?'Open position':rows(d['people']).where((u)=>u['id']==p['userId']).firstOrNull?['fullName']?.toString()??'Employee unavailable';
 String dept(Map<String,dynamic> p)=>p['departmentId']==null?'Company-wide':depts.where((x)=>x['id']==p['departmentId']).firstOrNull?['name']?.toString()??'Department unavailable';
 String title(String kind,Map<String,dynamic> p)=>kind=='position'?role(p):(p['name']??p['fullName']??'Unavailable').toString();
 void zoom(double delta){final previous=transform.value.getMaxScaleOnAxis();final scale=(previous+delta).clamp(.2,1.6).toDouble();final center=viewport==null?Offset.zero:viewport!.center(Offset.zero);final scene=transform.toScene(center);final m=Matrix4.diagonal3Values(scale,scale,1);m.setTranslationRaw(center.dx-scene.dx*scale,center.dy-scene.dy*scale,0);transform.value=m;}
 void openReadable(HierarchyLayout graph){
  final size=viewport;if(size==null||size.width<=0)return;
  final scale=math.min(1.0,math.max(.85,size.width/graph.width));
  final m=Matrix4.diagonal3Values(scale,scale,1);
  m.setTranslationRaw(size.width/2-graph.root.center.dx*scale,8,0);transform.value=m;
 }
 Widget rootCard(String kind){
  final t=Theme.of(context);final s=t.colorScheme;
  return target('root-'+kind,null,(highlight)=>Material(
   color:highlight?s.primaryContainer:Color.alphaBlend(s.primary.withValues(alpha:.09),s.surface),
   borderRadius:BorderRadius.circular(16),child:InkWell(onTap:widget.busy?null:()=>applyTarget('root-'+kind,null),borderRadius:BorderRadius.circular(16),
    child:Container(decoration:BoxDecoration(border:Border.all(color:s.primary,width:highlight?3:1.4),borderRadius:BorderRadius.circular(16)),padding:const EdgeInsets.all(9),child:Row(children:[
     Icon(Icons.apartment_rounded,color:s.primary,size:29),const SizedBox(width:8),
     Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Tooltip(message:d['companyAdministrator']?.toString()??'Company administrator',child:CopyText('Company (Admin)',style:t.textTheme.titleSmall,maxLines:1,overflow:TextOverflow.ellipsis)),
      CopyText('Drop here to make top-level',style:t.textTheme.bodySmall?.copyWith(height:1.15),maxLines:2,overflow:TextOverflow.ellipsis),
     ])),
    ])))));
 }
 void fit(HierarchyLayout graph){final size=viewport;if(size==null||size.width<=0||size.height<=0)return;final scale=math.min(size.width/graph.width,size.height/graph.height).clamp(.2,1.0).toDouble();final m=Matrix4.diagonal3Values(scale,scale,1);m.setTranslationRaw(math.max(0.0,(size.width-graph.width*scale)/2),math.max(0.0,(size.height-graph.height*scale)/2),0);transform.value=m;}
 Widget feedback(String text)=>Material(color:Colors.transparent,child:Container(width:210,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Theme.of(context).colorScheme.primary,borderRadius:BorderRadius.circular(18)),child:Text(text,style:TextStyle(color:Theme.of(context).colorScheme.onPrimary,fontWeight:FontWeight.bold))));
 void edgePan(DragUpdateDetails details){
  final box=canvasKey.currentContext?.findRenderObject();if(box is! RenderBox)return;
  final at=box.globalToLocal(details.globalPosition);final size=box.size;
  if(at.dx < -12||at.dx>size.width+12||at.dy < -12||at.dy>size.height+12)return;
  double x=0,y=0;const edge=40.0;
  if(at.dx<edge)x=10;else if(at.dx>size.width-edge)x=-10;
  if(at.dy<edge)y=10;else if(at.dy>size.height-edge)y=-10;
  if(x!=0||y!=0){final m=Matrix4.copy(transform.value);final old=m.getTranslation();m.setTranslationRaw((old.x+x).clamp(-20000.0,20000.0).toDouble(),(old.y+y).clamp(-20000.0,20000.0).toDouble(),0);transform.value=m;}
 }
 void beginDrag(){setState(()=>dragging=true);}
 void endDrag(){if(mounted)setState(()=>dragging=false);}
 Widget drag(String kind,Map<String,dynamic> p,Widget child)=>LongPressDraggable<HierarchyDrag>(
  data:HierarchyDrag(kind,p),maxSimultaneousDrags:widget.busy?0:1,
  dragAnchorStrategy:pointerDragAnchorStrategy,feedback:feedback(title(kind,p)),
  onDragStarted:beginDrag,onDragUpdate:edgePan,onDragEnd:(_)=>endDrag(),
  childWhenDragging:Opacity(opacity:.45,child:child),child:child);
 Widget handle(String kind,Map<String,dynamic> p)=>Draggable<HierarchyDrag>(
  data:HierarchyDrag(kind,p),maxSimultaneousDrags:widget.busy?0:1,
  dragAnchorStrategy:pointerDragAnchorStrategy,feedback:feedback(title(kind,p)),
  onDragStarted:beginDrag,onDragUpdate:edgePan,onDragEnd:(_)=>endDrag(),
  child:Tooltip(message:'Drag to move',child:SizedBox(key:ValueKey('drag-$kind-${p['id']??p['code']}'),width:42,height:42,child:const Icon(Icons.drag_indicator_rounded))));
 void select(HierarchyDrag item){setState(()=>picked=item);}
 void applyTarget(String kind,Map<String,dynamic>? p){
  final item=picked;if(item==null)return;
  final change=hierarchyChange(d,item,kind,p);
  if(change!=null){setState(()=>picked=null);widget.onChange(change);}
 }

 Widget target(String kind,Map<String,dynamic>? p,Widget Function(bool) child)=>DragTarget<HierarchyDrag>(
  onWillAcceptWithDetails:(x)=>!widget.busy&&hierarchyChange(d,x.data,kind,p)!=null,
  onAcceptWithDetails:(x){final change=hierarchyChange(d,x.data,kind,p);if(change!=null){setState(()=>picked=null);widget.onChange(change);}},
  builder:(c,candidates,rejected)=>child(candidates.isNotEmpty||(picked!=null&&hierarchyChange(d,picked!,kind,p)!=null)));
 Widget node(String kind,Map<String,dynamic> p){
  final t=Theme.of(context);final name=title(kind,p);
  final sub=kind=='position'?person(p):positions.where((x)=>x['departmentId']==p['id']).length.toString()+' positions';
  final matches=search.isEmpty||[name,sub,if(kind=='position')dept(p)].join(' ').toLowerCase().contains(search);
  return target(kind,p,(highlight){
   final s=t.colorScheme;
   final card=Material(key:ValueKey('node-'+kind+'-'+p['id'].toString()),color:highlight?s.primaryContainer:s.surface,borderRadius:BorderRadius.circular(16),elevation:highlight?5:2,shadowColor:s.primary.withValues(alpha:.20),clipBehavior:Clip.antiAlias,child:InkWell(
    onTap:widget.busy?null:()=>picked!=null?applyTarget(kind,p):widget.onEdit(p,kind),
    child:Stack(children:[
     Positioned(left:0,top:0,bottom:0,child:Container(width:4,color:s.primary)),
     Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(border:Border.all(color:highlight?s.primary:s.outlineVariant,width:highlight?2:1),borderRadius:BorderRadius.circular(16)))),
     Padding(padding:const EdgeInsets.fromLTRB(11,8,4,8),child:Row(children:[
      Container(width:32,height:36,decoration:BoxDecoration(color:s.primary.withValues(alpha:.12),borderRadius:BorderRadius.circular(10)),child:Icon(kind=='position'?Icons.person_outline_rounded:Icons.apartment_rounded,color:s.primary,size:21)),
      const SizedBox(width:8),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
       CopyText(name,style:t.textTheme.titleSmall?.copyWith(fontWeight:FontWeight.w800,height:1.15),maxLines:2,overflow:TextOverflow.ellipsis),
       const SizedBox(height:4),CopyText(sub,style:t.textTheme.bodySmall?.copyWith(height:1.15),maxLines:1,overflow:TextOverflow.ellipsis),
       if(kind=='position')CopyText(dept(p),style:t.textTheme.bodySmall?.copyWith(height:1.15),maxLines:1,overflow:TextOverflow.ellipsis),
      ])),
      handle(kind,p),
     ])),
    ])));
   return drag(kind,p,Opacity(opacity:matches||highlight?1:.38,child:card));
  });
 }
 Widget roster(String label,String kind,List<Map<String,dynamic>> records){
  return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   CopyText(label,style:Theme.of(context).textTheme.titleSmall),const SizedBox(height:6),
   if(records.isEmpty)const CopyText('No available items')else SizedBox(height:64,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:records.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(c,i){
    final p=records[i];
    final chip=TideSurface(onTap:widget.busy?null:()=>kind=='department'&&picked!=null?applyTarget(kind,p):select(HierarchyDrag(kind,p)),tinted:picked?.kind==kind&&picked?.row==p,padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(kind=='person'?Icons.person_outline:kind=='role'?Icons.badge_outlined:Icons.apartment_outlined,size:20),const SizedBox(width:8),ConstrainedBox(constraints:const BoxConstraints(maxWidth:170),child:CopyText(title(kind,p),maxLines:2,overflow:TextOverflow.ellipsis)),const SizedBox(width:4),if(kind!='department')handle(kind,p)else const Icon(Icons.arrow_downward_rounded,size:19)]));
    return Center(child:kind=='department'?target(kind,p,(highlight)=>Container(decoration:BoxDecoration(border:Border.all(color:highlight?Theme.of(c).colorScheme.primary:Colors.transparent,width:2),borderRadius:BorderRadius.circular(20)),child:chip)):drag(kind,p,chip));
   })),
  ]);
 }
 @override Widget build(BuildContext c){
  final kind=departments?'department':'position';final records=departments?depts:positions;
  final scale=MediaQuery.textScalerOf(c).scale(14)/14;
  final graph=HierarchyLayout(records,departments?'parentDepartmentId':'parentPositionId',nodeW:math.max(228.0,228*scale),nodeH:math.max(104.0,104*scale));
  final t=Theme.of(c);
  final keyboard=MediaQuery.viewInsetsOf(c).bottom>0;
  return LayoutBuilder(builder:(c,bounds){
   if(bounds.maxHeight<180)return const Center(child:CopyText('Use a taller window to edit the chart.'));
   return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    if(!keyboard)Row(children:[
     Expanded(child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:7),decoration:BoxDecoration(color:t.colorScheme.primary.withValues(alpha:.08),borderRadius:BorderRadius.circular(14)),child:Row(children:[
      Icon(Icons.open_with_rounded,size:17,color:t.colorScheme.primary),const SizedBox(width:6),
      Expanded(child:CopyText('Drag cards · Pinch to zoom',style:t.textTheme.bodySmall?.copyWith(height:1.15))),
     ]))),
     IconButton(tooltip:'Fit chart',onPressed:()=>fit(graph),icon:const Icon(Icons.fit_screen_outlined)),
     IconButton(tooltip:'Zoom out',onPressed:()=>zoom(-.15),icon:const Icon(Icons.remove)),
     IconButton(tooltip:'Zoom in',onPressed:()=>zoom(.15),icon:const Icon(Icons.add)),
    ]),
    if(widget.busy)const LinearProgressIndicator(),
    if(picked!=null)Padding(padding:const EdgeInsets.only(bottom:6),child:Row(children:[Expanded(child:CopyText('Selected: '+title(picked!.kind,picked!.row)+' · tap a highlighted destination',style:t.textTheme.labelMedium)),IconButton(tooltip:'Cancel selection',onPressed:()=>setState(()=>picked=null),icon:const Icon(Icons.close))])),
    Expanded(child:records.isEmpty?const Center(child:TideEmpty(message:'No positions or departments configured.')):Container(
     key:const ValueKey('hierarchy-canvas'),clipBehavior:Clip.antiAlias,decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[t.colorScheme.surface,t.colorScheme.primary.withValues(alpha:.10)]),border:Border.all(color:t.colorScheme.outlineVariant),borderRadius:BorderRadius.circular(22)),
     child:LayoutBuilder(builder:(c,b){viewport=Size(b.maxWidth,b.maxHeight);if(!initialized){initialized=true;WidgetsBinding.instance.addPostFrameCallback((_) {if(mounted){final target=graph.rects[widget.initialFocusId];if(target==null){openReadable(graph);}else{final size=viewport!;final scale=math.min(1.0,math.min(size.width/target.width,size.height/target.height)).clamp(.2,1.0).toDouble();final m=Matrix4.diagonal3Values(scale,scale,1);m.setTranslationRaw(size.width/2-target.center.dx*scale,size.height/2-target.center.dy*scale,0);transform.value=m;}}});}return InteractiveViewer(key:canvasKey,transformationController:transform,constrained:false,panEnabled:!dragging,scaleEnabled:!dragging,boundaryMargin:const EdgeInsets.all(300),minScale:.2,maxScale:1.6,
      child:SizedBox(width:graph.width,height:graph.height,child:Stack(children:[
       Positioned.fill(child:CustomPaint(painter:_Links(graph,t.colorScheme.primary.withValues(alpha:.65)))),
       Positioned.fromRect(rect:graph.root,child:rootCard(kind)),
       for(final p in records)if(graph.rects[p['id']]!=null)Positioned.fromRect(rect:graph.rects[p['id']]!,child:node(kind,p)),
      ])));}),
    )),
    if(!departments&&!keyboard&&bounds.maxHeight>240)...[
     const SizedBox(height:5),
     Material(color:t.colorScheme.surface,elevation:3,shadowColor:t.colorScheme.primary.withValues(alpha:.15),borderRadius:const BorderRadius.vertical(top:Radius.circular(26)),clipBehavior:Clip.antiAlias,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
      InkWell(onTap:()=>setState(()=>trayExpanded=!trayExpanded),child:Padding(padding:const EdgeInsets.fromLTRB(12,5,8,2),child:Row(children:[
       Expanded(child:Center(child:Container(width:34,height:4,decoration:BoxDecoration(color:t.colorScheme.outline,borderRadius:BorderRadius.circular(5))))),
       Icon(trayExpanded?Icons.expand_more_rounded:Icons.expand_less_rounded,size:22,color:t.colorScheme.primary),
      ]))),
      if(trayExpanded)...[
       Padding(padding:const EdgeInsets.symmetric(horizontal:7),child:Row(children:[
        for(final x in const [('person','Employees',Icons.person_outline),('role','Roles',Icons.badge_outlined),('department','Departments',Icons.layers_outlined)])Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:2),child:_HierarchySegment(label:x.$2,icon:x.$3,selected:tray==x.$1,onTap:()=>setState((){tray=x.$1;picked=null;})))),
       ])),
       Padding(padding:const EdgeInsets.fromLTRB(8,5,8,7),child:roster(tray=='person'?'Drag or tap employee':tray=='role'?'Drag or tap role':'Drop position here to transfer',tray,tray=='person'?rows(d['people']):tray=='role'?rows(d['roles']):depts)),
      ]else Padding(padding:const EdgeInsets.fromLTRB(14,0,14,8),child:CopyText('Employees · Roles · Departments',style:t.textTheme.bodySmall)),
     ])),
    ],

   ]);
  });
 }
}

class HierarchyLayout{
 final Map<dynamic,Rect> rects={};final List<(dynamic,dynamic)> edges=[];final List<dynamic> roots=[];late final Rect root;
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
   rects[id]=Rect.fromLTWH(x,102+depth*(nodeH+34),nodeW,nodeH);return x;
  }
  for(final p in records){if(!byId.containsKey(p[parent])||p[parent]==p['id']){if(!visited.contains(p['id'])){roots.add(p['id']);place(p['id'],0);}}}
  for(final p in records){if(!visited.contains(p['id'])){roots.add(p['id']);place(p['id'],0);}}
  width=math.max(nodeW+36,cursor);height=math.max(180.0,120+(deepest+1)*nodeH+deepest*34);
  final center=roots.isEmpty?width/2:(rects[roots.first]!.center.dx+rects[roots.last]!.center.dx)/2;
  root=Rect.fromLTWH(center-nodeW/2,12,nodeW,76);
 }
}
class _Links extends CustomPainter{
 final HierarchyLayout graph;final Color color;const _Links(this.graph,this.color);
 @override void paint(Canvas canvas,Size size){
  final pen=Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=2;
  for(final id in graph.roots){final a=graph.root.bottomCenter,b=graph.rects[id]!.topCenter,mid=(a.dy+b.dy)/2;canvas.drawPath(Path()..moveTo(a.dx,a.dy)..lineTo(a.dx,mid)..lineTo(b.dx,mid)..lineTo(b.dx,b.dy),pen);}
  for(final e in graph.edges){final a=graph.rects[e.$1]!,b=graph.rects[e.$2]!;final start=a.bottomCenter,end=b.topCenter,mid=(start.dy+end.dy)/2;
   canvas.drawPath(Path()..moveTo(start.dx,start.dy)..lineTo(start.dx,mid)..lineTo(end.dx,mid)..lineTo(end.dx,end.dy),pen);}
 }
 @override bool shouldRepaint(covariant _Links old)=>old.graph!=graph||old.color!=color;
}

class _HierarchySegment extends StatelessWidget{
 final String label;final IconData icon;final bool selected;final VoidCallback onTap;
 const _HierarchySegment({required this.label,required this.icon,required this.selected,required this.onTap});
 @override Widget build(BuildContext c){
  final s=Theme.of(c).colorScheme;
  return Semantics(button:true,selected:selected,label:tr(c,label),child:Material(color:selected?s.primary:s.surface,borderRadius:BorderRadius.circular(13),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(13),child:Container(height:44,padding:const EdgeInsets.symmetric(horizontal:5),decoration:BoxDecoration(border:Border.all(color:selected?s.primary:s.outlineVariant),borderRadius:BorderRadius.circular(13)),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
   Icon(icon,size:17,color:selected?s.onPrimary:s.primary),const SizedBox(width:4),
   Flexible(child:CopyText(label,style:TextStyle(color:selected?s.onPrimary:s.onSurface,fontSize:12,fontWeight:FontWeight.w700),maxLines:1,overflow:TextOverflow.ellipsis)),
  ])))));
 }
}
