import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcolda/api.dart';
import 'package:idcolda/catalog.dart';

http.Response jsonResponse(Object x,[int status=200])=>http.Response(jsonEncode(x),status,headers:{'content-type':'application/json'});
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUp(()=>FlutterSecureStorage.setMockInitialValues({}));
 test('catalog includes exactly 151 unique reviewed operations',()async{final c=await Catalog.load();expect(c.operations.length,151);expect(c.operations.map((o)=>'${o.method} ${o.path}').toSet().length,151);expect(c.op('POST','/commands/dispatches/verify-completion-otp').fields.any((x)=>x['key']=='code'),true);});
 test('login and selected workspace use bearer authentication and workspace ticket',()async{
  final mock=MockClient((r)async{
    expect(r.url.scheme,'https');expect(r.url.host,host);
    switch(r.url.path){
      case '/api/v1/auth/login': expect(jsonDecode(r.body)['companySlug'],'sample');expect(r.headers['Authorization'],isNull);return jsonResponse({'accessToken':'test-access','refreshToken':'test-refresh'});
      case '/api/v1/auth/me': expect(r.headers['Authorization'],'Bearer test-access');return jsonResponse({'userId':1,'isSuperAdmin':true,'accountStatus':'Approved'});
      case '/api/v1/workspace/select': expect(jsonDecode(r.body)['companyId'],12);return jsonResponse({'workspaceTicket':'test-workspace'});
      case '/api/v1/dashboard': expect(r.headers['X-IDCOLDA-Workspace'],'test-workspace');return jsonResponse({'activeMembers':4});
      default:return jsonResponse({},404);
    }
  });final a=Api(client:mock);await a.login('test@example.com','not-real',slug:'sample');await a.selectWorkspace(12);expect(obj(await a.get('/dashboard'))['activeMembers'],4);await a.clear();a.dispose();
 });
 test('401 on write renews session but never replays the mutation',()async{
  var writes=0,refreshes=0;
  final mock=MockClient((r)async{switch(r.url.path){case '/api/v1/auth/login':return jsonResponse({'accessToken':'old','refreshToken':'r1'});case '/api/v1/auth/me':return jsonResponse({'userId':1,'accountStatus':'Approved'});case '/api/v1/clients':writes++;return jsonResponse({},401);case '/api/v1/auth/refresh':refreshes++;expect(jsonDecode(r.body)['refreshToken'],'r1');return jsonResponse({'accessToken':'new','refreshToken':'r2'});default:return jsonResponse({},404);}});
  final a=Api(client:mock);await a.login('test@example.com','test');await expectLater(a.request('POST','/clients',mode:'raw',data:{'name':'Test'}),throwsA(isA<ApiFailure>()));expect(writes,1);expect(refreshes,1);await a.clear();a.dispose();
 });
 test('concurrent refreshes share one rotation',()async{var rotations=0;final mock=MockClient((r)async{if(r.url.path.endsWith('/login'))return jsonResponse({'accessToken':'a','refreshToken':'r'});if(r.url.path.endsWith('/me'))return jsonResponse({'userId':1,'accountStatus':'Approved'});if(r.url.path.endsWith('/refresh')){rotations++;await Future<void>.delayed(const Duration(milliseconds:20));return jsonResponse({'accessToken':'b','refreshToken':'s'});}return jsonResponse({},404);});final a=Api(client:mock);await a.login('test@example.com','test');await Future.wait([a.refresh(),a.refresh(),a.refresh()]);expect(rotations,1);await a.clear();a.dispose();});
 test('reject paths that could redirect API credentials',()async{final a=Api(client:MockClient((_)async=>throw StateError('Network must not be called')));await expectLater(a.get('/../private',auth:false),throwsA(isA<ApiFailure>()));await expectLater(a.get('https://other.example',auth:false),throwsA(isA<ApiFailure>()));a.dispose();});
}
