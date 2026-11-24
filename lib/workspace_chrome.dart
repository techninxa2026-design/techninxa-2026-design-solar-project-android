import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'copy.dart';

/// Both navigation surfaces use the same solid, contrast-safe workspace color.
Color workspaceBarColor(BuildContext context)=>
 Theme.of(context).appBarTheme.backgroundColor??const Color(0xff087eb1);
const workspaceBarShape=BorderRadius.vertical(bottom:Radius.circular(26));

class WorkspaceHeader extends StatelessWidget implements PreferredSizeWidget{
 final Widget logo;final String title,subtitle;final int unread;final bool approved;
 final VoidCallback onNotifications,onAccount,onSearch;
 const WorkspaceHeader({super.key,required this.logo,required this.title,required this.subtitle,required this.unread,required this.approved,required this.onNotifications,required this.onAccount,required this.onSearch});
 @override Size get preferredSize=>Size.fromHeight(approved?126:68);
 @override Widget build(BuildContext c){
  final color=workspaceBarColor(c);
  return AnnotatedRegion<SystemUiOverlayStyle>(
   value:SystemUiOverlayStyle.light.copyWith(statusBarColor:Colors.transparent),
   child:Material(color:color,borderRadius:workspaceBarShape,clipBehavior:Clip.antiAlias,child:SafeArea(bottom:false,child:Padding(
    padding:const EdgeInsets.fromLTRB(14,4,14,10),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
     SizedBox(height:54,child:Row(children:[
      logo,const SizedBox(width:10),
      Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
       CopyText(title,style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800,height:1.2),maxLines:1,overflow:TextOverflow.ellipsis),
       const SizedBox(height:3),
       CopyText(subtitle,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w500,height:1.2),maxLines:1,overflow:TextOverflow.ellipsis),
      ])),
      const SizedBox(width:4),
      IconButton(tooltip:'Notifications',color:Colors.white,onPressed:onNotifications,icon:Badge(isLabelVisible:unread>0,backgroundColor:Colors.white,textColor:color,label:Text(unread>99?'99+':unread.toString()),child:const Icon(Icons.notifications_rounded,size:24))),
      IconButton(tooltip:'Account',color:Colors.white,onPressed:onAccount,icon:const Icon(Icons.account_circle_rounded,size:27)),
     ])),
     if(approved)...[
      const SizedBox(height:7),
      Material(color:Colors.white.withValues(alpha:.14),borderRadius:BorderRadius.circular(15),child:InkWell(onTap:onSearch,borderRadius:BorderRadius.circular(15),child:SizedBox(height:47,child:Padding(padding:const EdgeInsets.symmetric(horizontal:13),child:Row(children:[
       const Icon(Icons.search_rounded,color:Colors.white,size:23),const SizedBox(width:10),
       const Expanded(child:CopyText('Find a feature',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w500),maxLines:1,overflow:TextOverflow.ellipsis)),
       const Icon(Icons.arrow_forward_rounded,color:Colors.white,size:20),
      ]))))),
     ],
    ]),
   ))),
  );
 }
}
class WorkspaceNavItem{
 final String key,label;final IconData icon;
 const WorkspaceNavItem(this.key,this.label,this.icon);
}
class WorkspaceNavigation extends StatelessWidget{
 final List<WorkspaceNavItem> items;final String selected;final ValueChanged<String> onSelect;
 const WorkspaceNavigation({super.key,required this.items,required this.selected,required this.onSelect});
 @override Widget build(BuildContext c){
  final color=workspaceBarColor(c);
  // Match the supplied reference: one continuous strip, square top edge,
  // curved lower corners, evenly spaced icon-only destinations.
  return AnnotatedRegion<SystemUiOverlayStyle>(
   value:SystemUiOverlayStyle.light.copyWith(systemNavigationBarColor:Theme.of(c).scaffoldBackgroundColor,systemNavigationBarIconBrightness:Theme.of(c).brightness==Brightness.dark?Brightness.light:Brightness.dark),
   child:SafeArea(top:false,minimum:const EdgeInsets.only(bottom:3),child:Material(
    key:const ValueKey('workspace-navigation-strip'),
    color:color,borderRadius:workspaceBarShape,clipBehavior:Clip.antiAlias,
    child:SizedBox(height:58,child:Row(children:items.map((n){
     final active=n.key==selected;
     return Expanded(child:Semantics(button:true,selected:active,label:tr(c,n.label),
      child:Tooltip(message:tr(c,n.label),excludeFromSemantics:true,child:InkWell(
       key:ValueKey('nav-'+n.key),onTap:()=>onSelect(n.key),splashColor:Colors.white24,highlightColor:Colors.white12,
       child:Center(child:AnimatedContainer(
        duration:MediaQuery.disableAnimationsOf(c)?Duration.zero:const Duration(milliseconds:180),
        width:48,height:42,decoration:BoxDecoration(color:active?Colors.white.withValues(alpha:.17):Colors.transparent,borderRadius:BorderRadius.circular(14)),
        child:Icon(n.icon,size:26,color:Colors.white),
       )),
      ))));
    }).toList())),
   )),
  );
 }
}
