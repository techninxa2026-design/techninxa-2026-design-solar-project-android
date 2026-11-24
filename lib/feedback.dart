import 'package:flutter/material.dart';
import 'copy.dart';

enum FeedbackKind { success, error, info }
final feedbackMessenger=GlobalKey<ScaffoldMessengerState>();

/// Root messenger survives sign-in/out and form route transitions.
void showFeedback(String message,{FeedbackKind kind=FeedbackKind.info,BuildContext? context,String? title}){
 final messenger=feedbackMessenger.currentState??(context!=null&&context.mounted?ScaffoldMessenger.maybeOf(context):null);
 if(messenger==null)return;
 final theme=Theme.of(messenger.context);
 final s=theme.colorScheme;
 final accent=switch(kind){FeedbackKind.success=>theme.brightness==Brightness.dark?const Color(0xff80e4bd):const Color(0xff08795b),FeedbackKind.error=>s.error,FeedbackKind.info=>s.primary};
 final heading=title??switch(kind){FeedbackKind.success=>'Successful',FeedbackKind.error=>'Action unsuccessful',FeedbackKind.info=>'IDCOLDA'};
 final icon=switch(kind){FeedbackKind.success=>Icons.check_circle_outline_rounded,FeedbackKind.error=>Icons.error_outline_rounded,FeedbackKind.info=>Icons.info_outline_rounded};
 messenger.hideCurrentSnackBar();
 messenger.showSnackBar(SnackBar(behavior:SnackBarBehavior.floating,backgroundColor:Colors.transparent,elevation:0,padding:EdgeInsets.zero,
  margin:const EdgeInsets.fromLTRB(14,8,14,12),duration:Duration(seconds:kind==FeedbackKind.error?6:4),
  content:Material(color:s.surface,elevation:7,shadowColor:Colors.black26,borderRadius:BorderRadius.circular(20),clipBehavior:Clip.antiAlias,
   child:Semantics(liveRegion:true,child:IntrinsicHeight(child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Container(width:5,color:accent),
    Expanded(child:Padding(padding:const EdgeInsets.fromLTRB(12,12,4,12),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Container(width:40,height:40,decoration:BoxDecoration(color:accent.withValues(alpha:.13),borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:accent,size:23)),
     const SizedBox(width:11),Expanded(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      CopyText(heading,style:theme.textTheme.titleSmall?.copyWith(color:accent,fontWeight:FontWeight.w800)),
      const SizedBox(height:4),CopyText(message,style:theme.textTheme.bodyMedium?.copyWith(color:s.onSurface),maxLines:5,overflow:TextOverflow.ellipsis),
     ])),
    ]))),
    Align(alignment:Alignment.topCenter,child:IconButton(tooltip:'Dismiss message',onPressed:()=>messenger.hideCurrentSnackBar(),icon:Icon(Icons.close_rounded,color:s.onSurfaceVariant,size:19))),
   ]))))));
}
