import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'copy.dart';

class AndroidRelease {
 final int code,bytes;
 final String version,sha256,notes;
 final bool prompt;
 const AndroidRelease(this.code,this.bytes,this.version,this.sha256,this.notes,this.prompt);
 static AndroidRelease? parse(Object? value){
  if(value is! Map||value['available']!=true)return null;
  final code=value['versionCode'], bytes=value['bytes'], hash=value['sha256'],version=value['versionName'];
  if(code is! int||code<=0||code>2147483647||bytes is! int||bytes<=0||bytes>200*1024*1024||
     hash is! String||!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)||version is! String||version.isEmpty)return null;
  return AndroidRelease(code,bytes,version,hash,value['notes'] is String?value['notes'] as String:'',value['promptEnabled']==true);
 }
 bool isNewerThan(int installed)=>code>installed;
 bool shouldPrompt(int installed)=>prompt&&isNewerThan(installed);
}

/// One coordinator per app lifetime. Network failures never block sign-in.
class AndroidUpdateCoordinator with WidgetsBindingObserver {
 AndroidUpdateCoordinator(this.navigator,this.ready);
 final GlobalKey<NavigatorState> navigator;
 final bool Function() ready;
 static const channel=MethodChannel('idcolda/updates');
 final http.Client _client=http.Client();
 Timer? _timer;
 bool _checking=false,_disposed=false,_foreground=true;
 int? _lastPrompt;
 void start(){
  if(!Platform.isAndroid)return;
  WidgetsBinding.instance.addObserver(this);
  _timer=Timer.periodic(const Duration(seconds:60),(_)=>check());
  WidgetsBinding.instance.addPostFrameCallback((_)=>check());
 }
 @override void didChangeAppLifecycleState(AppLifecycleState state){
  _foreground=state==AppLifecycleState.resumed;
  if(_foreground)check();
 }
 Future<void> check({bool manual=false})async{
  if(!Platform.isAndroid||_disposed||_checking||!_foreground||!ready())return;
  _checking=true;
  try{
   final installed=await channel.invokeMapMethod<String,dynamic>('installedVersion');
   final code=installed?['code'];if(code is! int)throw StateError('installed version unavailable');
   final request=http.Request('GET',Uri.https('idcoldrs.com','/api/v1/public/android-release'))..followRedirects=false;
   request.headers['Cache-Control']='no-cache, no-store';
   final response=await _client.send(request).timeout(const Duration(seconds:10));
   if(response.statusCode!=200){await response.stream.drain<void>().timeout(const Duration(seconds:10));throw StateError('unavailable');}
   final data=<int>[];
   await for(final part in response.stream.timeout(const Duration(seconds:10))){
    if(data.length+part.length>16384)throw StateError('metadata');
    data.addAll(part);
   }
   final decoded=jsonDecode(utf8.decode(data));
   final release=AndroidRelease.parse(decoded);
   if(release==null&&(decoded is! Map||decoded['available']!=false))throw const FormatException('Invalid update manifest');
   if(_disposed||!_foreground||!ready())return;
   final nav=navigator.currentState;
   if(nav==null||!nav.mounted)return;
   if(release==null||!release.isNewerThan(code)){
    if(manual)ScaffoldMessenger.maybeOf(nav.context)?.showSnackBar(const SnackBar(content:Text('No newer version is available.')));
    return;
   }
   if(!manual&&(!release.shouldPrompt(code)||_lastPrompt==release.code||nav.canPop()))return;
   _lastPrompt=release.code;
   final refresh=await showDialog<bool>(context:nav.context,barrierDismissible:false,builder:(_)=>_UpdateDialog(release:release));
   if(refresh==true&&!_disposed){_lastPrompt=null;_checking=false;await check(manual:true);}
  }catch(_){
   if(manual&&!_disposed){final context=navigator.currentContext;if(context!=null&&context.mounted)ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content:Text('Could not check for updates. Try again later.')));}
  }finally{_checking=false;}
 }
 void dispose(){_disposed=true;_timer?.cancel();WidgetsBinding.instance.removeObserver(this);_client.close();}
}

class _UpdateDialog extends StatefulWidget{
 final AndroidRelease release;
 const _UpdateDialog({required this.release});
 @override State<_UpdateDialog> createState()=>_UpdateDialogState();
}
class _UpdateDialogState extends State<_UpdateDialog>{
 final busy=false.obs,progress=0.obs;
 final message=''.obs;
 @override void initState(){
  super.initState();
  AndroidUpdateCoordinator.channel.setMethodCallHandler((call)async{
   if(call.method=='progress'&&mounted&&call.arguments is int)progress.value=(call.arguments as int).clamp(0,100).toInt();
  });
 }
 Future<void> install()async{
  if(busy.value)return;
  busy.value=true;progress.value=0;message.value='';
  final r=widget.release;
  try{
   final result=await AndroidUpdateCoordinator.channel.invokeMethod<String>('install',{'code':r.code,'bytes':r.bytes,'sha256':r.sha256});
   if(!mounted)return;
   if(result=='permission'){message.value='Allow installation from IDCOLDA in Android Settings, return here, then tap Update now again.';}
   else if(result=='installer'){busy.value=false;Navigator.pop(context);}
   else {message.value='Unable to start installation. Try again.';}
  }on PlatformException catch(e){
   if(mounted&&e.code=='release_changed'){busy.value=false;Navigator.pop(context,true);return;}
   if(mounted)message.value=switch(e.code){
    'verification'=>'This update is not compatible with your installed app. Contact your administrator.',
    'download'=>'Download failed. Check your internet connection and try again.',
    'permission'=>'Unable to open installation settings.',
    _=>'Unable to install the update. Try again.'
   };
  }catch(_){if(mounted)message.value='Unable to update. Try again.';}
  finally{if(mounted)busy.value=false;}
 }
 @override void dispose(){AndroidUpdateCoordinator.channel.setMethodCallHandler(null);busy.close();progress.close();message.close();super.dispose();}
 @override Widget build(BuildContext context)=>Obx(()=>PopScope(canPop:!busy.value,child:AlertDialog(
  icon:Icon(Icons.system_update_rounded,color:Theme.of(context).colorScheme.primary,size:44),
  title:const CopyText('A new version is available'),
  content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
   CopyText('IDCOLDA '+widget.release.version+' • '+(widget.release.bytes/1048576).toStringAsFixed(1)+' MB'),
   const SizedBox(height:12),if(widget.release.notes.isNotEmpty)Text(widget.release.notes),
   const SizedBox(height:12),const CopyText('Download the verified update, then confirm installation in Android. Your existing app data is normally retained.'),
   if(busy.value)...[const SizedBox(height:16),LinearProgressIndicator(value:progress.value==0?null:progress.value/100),Text('Downloading… '+progress.value.toString()+'%')],
   if(message.value.isNotEmpty)...[const SizedBox(height:12),CopyText(message.value,style:TextStyle(color:Theme.of(context).colorScheme.error))]
  ])),
  actions:[TextButton(onPressed:busy.value?null:()=>Navigator.pop(context),child:const CopyText('Later')),
   FilledButton(onPressed:busy.value?null:install,child:const CopyText('Update now'))]
 )));
}
