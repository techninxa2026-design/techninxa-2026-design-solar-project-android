import 'package:flutter/material.dart';
import 'copy.dart';

class WorkspaceHeader extends StatelessWidget implements PreferredSizeWidget{
 final Widget logo;final String title,subtitle;final int unread;final bool approved;
 final VoidCallback onNotifications,onAccount,onSearch;
 const WorkspaceHeader({super.key,required this.logo,required this.title,required this.subtitle,required this.unread,required this.approved,required this.onNotifications,required this.onAccount,required this.onSearch});
 @override Size get preferredSize=>Size.fromHeight(approved?140:76);
 @override Widget build(BuildContext c){
  final t=Theme.of(c);final s=t.colorScheme;
  return Material(color:s.surface,child:SafeArea(bottom:false,child:Padding(padding:const EdgeInsets.fromLTRB(16,8,16,10),child:Column(children:[
   Row(children:[logo,const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    CopyText(title,style:t.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800,letterSpacing:-.5),maxLines:1,overflow:TextOverflow.ellipsis),
    CopyText(subtitle,style:t.textTheme.labelMedium?.copyWith(color:s.onSurfaceVariant),maxLines:1,overflow:TextOverflow.ellipsis),
   ])),const SizedBox(width:4),IconButton.filledTonal(tooltip:'Notifications',onPressed:onNotifications,icon:Badge(isLabelVisible:unread>0,label:Text(unread>99?'99+':unread.toString()),child:const Icon(Icons.notifications_none_rounded))),const SizedBox(width:3),IconButton(tooltip:'Account',onPressed:onAccount,icon:const Icon(Icons.account_circle_outlined,size:27))]),
   if(approved)...[const SizedBox(height:12),Material(color:s.surfaceContainerHighest,borderRadius:BorderRadius.circular(18),child:InkWell(onTap:onSearch,borderRadius:BorderRadius.circular(18),child:Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),child:Row(children:[Icon(Icons.search_rounded,color:s.primary,size:23),const SizedBox(width:11),Expanded(child:CopyText('Find a feature',style:t.textTheme.bodyMedium?.copyWith(color:s.onSurfaceVariant),maxLines:1,overflow:TextOverflow.ellipsis)),Icon(Icons.arrow_forward_rounded,color:s.primary,size:19)]))))],
  ]))));
 }
}
class WorkspaceNavItem{final String key,label;final IconData icon;const WorkspaceNavItem(this.key,this.label,this.icon);}
class WorkspaceNavigation extends StatelessWidget{
 final List<WorkspaceNavItem> items;final String selected;final ValueChanged<String> onSelect;
 const WorkspaceNavigation({super.key,required this.items,required this.selected,required this.onSelect});
 @override Widget build(BuildContext c){
  final t=Theme.of(c);final s=t.colorScheme;
  return Material(color:s.surface,elevation:0,child:SafeArea(top:false,child:Container(
   decoration:BoxDecoration(border:Border(top:BorderSide(color:s.outlineVariant))),
   padding:const EdgeInsets.fromLTRB(8,6,8,7),
   child:Row(children:items.map((n){
    final active=n.key==selected;
    return Expanded(child:Semantics(button:true,selected:active,label:tr(c,n.label),child:InkWell(onTap:()=>onSelect(n.key),borderRadius:BorderRadius.circular(18),child:Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Column(mainAxisSize:MainAxisSize.min,children:[
     AnimatedContainer(duration:MediaQuery.disableAnimationsOf(c)?Duration.zero:const Duration(milliseconds:180),width:52,height:34,decoration:BoxDecoration(color:active?s.primaryContainer:Colors.transparent,borderRadius:BorderRadius.circular(14)),child:Icon(n.icon,size:23,color:active?s.onPrimaryContainer:s.onSurfaceVariant)),
     const SizedBox(height:4),CopyText(n.label,style:t.textTheme.labelSmall?.copyWith(fontWeight:active?FontWeight.w800:FontWeight.w500,color:active?s.primary:s.onSurfaceVariant),maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center),
     const SizedBox(height:4),Container(width:active?18:0,height:3,decoration:BoxDecoration(color:s.primary,borderRadius:BorderRadius.circular(4))),
    ])))));
   }).toList()),
  )));
 }
}
