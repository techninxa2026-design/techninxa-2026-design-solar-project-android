import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'api.dart';
import 'copy.dart';
import 'tide_cards.dart';
import 'record_presentation.dart';

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
class _HierarchyBoardState extends State<HierarchyBoard>{
 bool departments=false;String search='';String tray='person';final transform=TransformationController();
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
   return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    ConstrainedBox(constraints:BoxConstraints(maxHeight:bounds.maxHeight*(keyboard ? 0.58 : 0.39)),child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       CopyText(d['companyAdministrator']?.toString()??'Company administrator',style:t.textTheme.titleMedium),
       const CopyText('Company-wide organizational root'),
      ])),if(!departments)IconButton.filledTonal(tooltip:'Create position',onPressed:widget.busy?null:widget.onCreate,icon:const Icon(Icons.add_rounded))]),
     const SizedBox(height:6),
     Wrap(spacing:8,runSpacing:4,children:[
      ChoiceChip(label:const CopyText('Reporting chart'),selected:!departments,onSelected:(_)=>setState(()=>departments=false)),
      ChoiceChip(label:const CopyText('Department chart'),selected:departments,onSelected:(_)=>setState(()=>departments=true)),
     ]),
     const SizedBox(height:6),
     TextField(onChanged:(v)=>setState(()=>search=v.trim().toLowerCase()),decoration:const InputDecoration(hintText:'Search hierarchy',prefixIcon:Icon(Icons.search_rounded),isDense:true)),
     const SizedBox(height:6),
     const CopyText('Hold a card and drag to move it. Tap a card to edit.'),
    ]))),
    if(!keyboard)...[
     Row(children:[Expanded(child:CopyText(departments?'Department tree':'Position tree',style:t.textTheme.titleSmall)),IconButton(tooltip:'Zoom out',onPressed:()=>zoom(-.15),icon:const Icon(Icons.remove)),IconButton(tooltip:'Reset zoom',onPressed:()=>transform.value=Matrix4.identity(),icon:const Icon(Icons.fit_screen_outlined)),IconButton(tooltip:'Zoom in',onPressed:()=>zoom(.15),icon:const Icon(Icons.add))]),
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
    if(!departments&&!keyboard)...[
     const SizedBox(height:8),
     ConstrainedBox(constraints:BoxConstraints(maxHeight:bounds.maxHeight*.28),child:SingleChildScrollView(child:TideSurface(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
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
