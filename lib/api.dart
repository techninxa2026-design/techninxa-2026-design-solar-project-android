import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const host = 'idcoldrs.com';
Map<String,dynamic> obj(dynamic v) => v is Map ? Map<String,dynamic>.from(v) : <String,dynamic>{};
List<Map<String,dynamic>> rows(dynamic v) => v is List ? v.whereType<Map>().map(obj).toList() : [];
class ApiFailure implements Exception {
  final int status;
  final String message;
  final String? code;
  final String? traceId;
  final List<String> fields;
  ApiFailure(this.status,this.message,[this.code,this.traceId,this.fields=const []]);
  @override String toString()=>[message,if(status>0)'HTTP $status',if(fields.isNotEmpty)'Check: ${fields.join(', ')}',if(traceId!=null)'Reference: $traceId'].join('\n');
}
class Upload {
  final String name;
  final Uint8List bytes;
  Upload(this.name,this.bytes);
}
class Api extends ChangeNotifier {
  final http.Client _http;
  final FlutterSecureStorage storage;
  Api({http.Client? client,FlutterSecureStorage? secureStorage}):_http=client??http.Client(),storage=secureStorage??const FlutterSecureStorage(aOptions:AndroidOptions(encryptedSharedPreferences:true));
  String? _access,_refresh,workspaceTicket;
  bool get signedIn=>_refresh!=null;
  Future<void>? _rotation;
  int _generation=0;
  Map<String,dynamic> me={};
  String get role => me['isSuperAdmin']==true && me['workspace']==null ? 'Admin' : obj(me['workspace'])['companyKind'].toString().toLowerCase().contains('installer') ? (me['isCompanyAdmin']==true?'Installer':'Worker') : 'DA';
  Set<String> get powers=> (me['effectivePowers'] is List ? me['effectivePowers'] as List : []).map((x)=>x.toString()).toSet();
  bool get superAdmin=>me['isSuperAdmin']==true;
  bool get companyAdmin=>me['isCompanyAdmin']==true;
  bool get approved=>me['accountStatus']=='Approved';
  static const _storeKey='idcolda.session.v1';
  Future<void> init() async {
    try { final x=obj(jsonDecode(await storage.read(key:_storeKey)??'{}'));_refresh=x['refreshToken'] as String?; if(_refresh!=null){await refresh();await loadMe();} }
    on ApiFailure catch(e){if(e.status==401)await clear();else rethrow;}
    catch(_){await clear();}
  }
  Future<void> _save(dynamic value,int generation) async {
    final x=obj(value);if(x['accessToken'] is! String||x['refreshToken'] is! String)throw ApiFailure(502,'Invalid authentication response.');
    if(generation!=_generation)throw ApiFailure(401,'Session changed.');
    await storage.write(key:_storeKey,value:jsonEncode({'refreshToken':x['refreshToken']}));
    if(generation!=_generation){await storage.delete(key:_storeKey);throw ApiFailure(401,'Session changed.');}
    _access=x['accessToken'];_refresh=x['refreshToken'];
  }
  Future<void> login(String email,String password,{String? slug,String? code,bool remember=true}) async {
    await clear(); final gen=_generation;
    final v=await request('POST','/auth/login',auth:false,mode:'raw',data:{'email':email.trim(),'password':password,if(slug!=null)'companySlug':slug,if(code!=null)'authenticatorCode':code});
    await _save(v,gen);if(!remember)await storage.delete(key:_storeKey);_remember=remember;await loadMe();
  }
  bool _remember=true;
  Future<void> refresh() async {
    if(_rotation!=null)return _rotation!;
    if(_refresh==null)throw ApiFailure(401,'Please sign in again.');
    final gen=_generation;final old=_refresh!;
    final task=() async {try{final v=await request('POST','/auth/refresh',auth:false,mode:'raw',data:{'refreshToken':old});await _save(v,gen);if(!_remember)await storage.delete(key:_storeKey);}on ApiFailure catch(e){if(e.status==401&&gen==_generation)await clear();rethrow;}}();
    _rotation=task;try{await task;}finally{if(identical(_rotation,task))_rotation=null;}
  }
  Future<void> loadMe() async {me=obj(await get('/auth/me'));notifyListeners();}
  Future<void> selectWorkspace(int id) async {final v=obj(await request('POST','/workspace/select',mode:'raw',data:{'companyId':id}));workspaceTicket=v['workspaceTicket'] as String?;if(workspaceTicket==null)throw ApiFailure(502,'Missing workspace ticket.');await loadMe();}
  Future<void> leaveWorkspace() async {workspaceTicket=null;await loadMe();}
  Future<void> clear() async {_generation++;_access=null;_refresh=null;workspaceTicket=null;me={};await storage.delete(key:_storeKey);notifyListeners();}
  Future<void> logout({bool all=false}) async {await request('POST',all?'/auth/logout-all':'/auth/logout');await clear();}
  Future<dynamic> get(String path,{Map<String,dynamic> query=const{},bool auth=true})=>request('GET',path,query:query,auth:auth);
  Future<Uint8List> bytes(String path,{bool auth=true}) async=>await request('GET',path,auth:auth,binary:true) as Uint8List;
  Future<dynamic> request(String method,String path,{bool auth=true,String mode='none',Map<String,dynamic> data=const{},Map<String,dynamic> query=const{},bool binary=false}) async {
    if(!path.startsWith('/')||path.contains('..')||path.contains('?')||path.contains('#')||path.contains('://'))throw ApiFailure(400,'Invalid API path.');
    if(auth&&_access==null)await refresh();
    if(path.startsWith('/commands/')&&method=='POST'&&mode!='urlencoded'&&mode!='formdata')throw ApiFailure(400,'This operation requires form data.');
    final used=_access;
    final resp=await _send(method,path,auth,mode,data,query,binary);
    if(resp.statusCode==401&&auth&&_refresh!=null){if(_access==used)await refresh(); if(method!='GET')throw ApiFailure(401,'Session renewed. Review and submit the action again.');return _decode(await _send(method,path,auth,mode,data,query,binary),binary);}
    return _decode(resp,binary);
  }
  Future<http.Response> _send(String method,String path,bool auth,String mode,Map<String,dynamic> data,Map<String,dynamic> query,bool binary) async {
    // Public logos are the only allowed non-API paths; never send bearer credentials there.
    final publicLogo=RegExp(r'^/company/[a-zA-Z0-9-]+/logo$').hasMatch(path);
    if(publicLogo&&auth)throw ApiFailure(400,'Public logo must be anonymous.');
    final uri=Uri.https(host,publicLogo?path:'/api/v1$path',query.isEmpty?null:query.map((k,v)=>MapEntry(k,v.toString())));
    final headers={'Accept':binary?'*/*':'application/json',if(auth&&_access!=null)'Authorization':'Bearer $_access',if(auth&&workspaceTicket!=null)'X-IDCOLDA-Workspace':workspaceTicket!};
    http.BaseRequest req;
    if(mode=='formdata'||mode=='urlencoded'){
      // Multipart supports repeated form keys by indexing arrays before submission.
      if(mode=='formdata'||data.values.any((v)=>v is Upload)){
        final m=http.MultipartRequest(method,uri);for(final e in data.entries){if(e.value is Upload){final u=e.value as Upload;m.files.add(http.MultipartFile.fromBytes(e.key,u.bytes,filename:u.name));}else if(e.value!=null)m.fields[e.key]=e.value.toString();} req=m;
      }else{final r=http.Request(method,uri);r.headers['Content-Type']='application/x-www-form-urlencoded; charset=utf-8';r.bodyFields={for(final e in data.entries)if(e.value!=null)e.key:e.value.toString()};req=r;}
    }else{final r=http.Request(method,uri);if(mode=='raw'){r.headers['Content-Type']='application/json';r.body=jsonEncode(data);}req=r;}
    req.headers.addAll(headers);req.followRedirects=false;
    try{return await (() async {final res=await _http.send(req);return http.Response.fromStream(res);})().timeout(const Duration(seconds:35));}
    on TimeoutException {throw ApiFailure(0,'Request timed out. Check the record before retrying a change.');}on http.ClientException{throw ApiFailure(0,'Connection failed. Check your internet connection.');}
  }
  // Only expose bounded application-level errors, never HTML, credentials or stack traces.
  String? _safeTitle(dynamic value){
    if(value is! String||value.isEmpty||value.length>500||
       RegExp(r'exception|stack trace|microsoft\\.|select\\s.+from|[<>\\r\\n]',caseSensitive:false).hasMatch(value))return null;
    return value;
  }
  String? _trace(http.Response r,Map<String,dynamic> e){
    final x=(e['traceId']??r.headers['x-idcolda-trace'])?.toString();
    return x!=null&&RegExp(r'^[A-Za-z0-9:._-]{1,128}$').hasMatch(x)?x:null;
  }
  dynamic _decode(http.Response r,bool binary){
    final status=r.statusCode;
    if(status>=200&&status<300){
      if(binary)return r.bodyBytes;
      if(r.bodyBytes.isEmpty)return null;
      try{return jsonDecode(utf8.decode(r.bodyBytes));}
      catch(_){throw ApiFailure(502,'Unexpected non-JSON API response. Check whether the request already saved before retrying.',null,_trace(r,{}));}
    }
    Map<String,dynamic> e={};
    try{e=obj(jsonDecode(utf8.decode(r.bodyBytes)));}catch(_){}
    final fields=<String>{};
    if(e['fields'] is List)fields.addAll((e['fields'] as List).whereType<String>());
    if(e['errors'] is Map)fields.addAll(obj(e['errors']).keys);
    final safeFields=fields.where((x)=>RegExp(r'^[A-Za-z0-9_.\\[\\]]{1,100}$').hasMatch(x)).take(15).toList();
    final fallback=switch(status){
      400=>'Check the submitted fields.',
      401=>'Authentication required or session expired.',
      403=>'You do not have access to this action.',
      404=>'Record not found.',
      405=>'This HTTP operation is not allowed by the server.',
      409=>'The record changed or additional verification is needed.',
      413=>'The submitted file or form is too large.',
      415=>'The server rejected the request content type.',
      429=>'Too many requests. Try again later.',
      503=>'The service is temporarily unavailable.',
      >=300 && <400=>'The API unexpectedly redirected. Check server authentication and routing.',
      _=>'Request failed.',
    };
    final detail=status>=400&&status<500?_safeTitle(e['title']):null;
    final code=e['code']?.toString();
    throw ApiFailure(status,detail??fallback,code,_trace(r,e),safeFields);
  }
  @override void dispose(){_http.close();super.dispose();}
}
