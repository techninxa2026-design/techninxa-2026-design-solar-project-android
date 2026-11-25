import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Route-owned state: no global cache or persistent company data.
class ReactiveResource<T> extends GetxController {
 ReactiveResource(this.loader):current=Rx<Future<T>>(Future<T>.sync(loader)){_track(current.value);}
 final Future<T> Function() loader;
 final Rx<Future<T>> current;
 Future<T>? _refreshing;
 bool _released=false;
 Future<T> get future=>current.value;
 Future<T> reload({bool coalesce=false}){
  if(_released)return Future<T>.error(StateError('Page closed'));
  if(coalesce&&_refreshing!=null)return _refreshing!;
  final next=Future<T>.sync(loader);
  _track(next);
  current.value=next;
  return next;
 }
 void _track(Future<T> next){
  _refreshing=next;
  next.then<void>((_){if(identical(_refreshing,next))_refreshing=null;},onError:(Object _,StackTrace __){if(identical(_refreshing,next))_refreshing=null;});
 }
 void release(){if(_released)return;_released=true;current.close();dispose();}
}
class ReactiveResourceBuilder<T> extends StatelessWidget {
 const ReactiveResourceBuilder({super.key,required this.resource,required this.builder});
 final ReactiveResource<T> resource;
 final AsyncWidgetBuilder<T> builder;
 @override Widget build(BuildContext context)=>Obx(()=>FutureBuilder<T>(future:resource.future,builder:builder));
}
class WorkspaceStateController extends GetxController {
 final page='home'.obs;
 final unread=0.obs;
 final revision=0.obs;
 bool _released=false;
 bool _polling=false;
 void select(String value){if(!_released)page.value=value;}
 void refreshHome(){if(!_released)revision.value++;}
 Future<void> refreshUnread(Future<int> Function() read)async{
  if(_released||_polling)return;
  _polling=true;
  try{final n=await read();if(!_released)unread.value=n<0?0:n;}catch(_){/* Retain count on transient failure. */}finally{_polling=false;}
 }
 void release(){if(_released)return;_released=true;page.close();unread.close();revision.close();dispose();}
}
