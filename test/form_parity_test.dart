import 'package:flutter_test/flutter_test.dart';
import 'package:idcolda/form_parity.dart';
import 'package:idcolda/catalog.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('Web scope forms submit only the deepest selection',(){
  final d=<String,dynamic>{'Name':'Sales','ZoneId':'1','DistrictId':'2','AreaId':'3','BranchId':'4','Track':'General'};
  normalizeTerritoryPayload('/commands/departments/create',d);
  expect(d,{'Name':'Sales','Track':'General','BranchId':'4'});
 });
 test('Warehouse preserves required zone and district and only one optional scope',(){
  final d=<String,dynamic>{'zoneId':'1','districtId':'2','areaId':'3','branchId':'4'};
  normalizeTerritoryPayload('/commands/inventory/create-warehouse',d);
  expect(d,{'zoneId':'1','districtId':'2','branchId':'4'});
 });
 test('Branch creation still submits all parent relationships',(){
  final d=<String,dynamic>{'zoneId':'1','districtId':'2','areaId':'3','name':'Branch'};
  normalizeTerritoryPayload('/commands/organization/create-branch',d);
  expect(d.length,4);
 });
 test('OTP completion takes precedence over persisted task state',(){
  expect(effectiveTaskStatus({'id':7,'status':'Open'},[7]),'Completed');
  expect(effectiveTaskStatus({'id':8,'status':'Open'},[7]),'Open');
 });
 test('MVC task and role field contracts and required references',()async{
  final c=await Catalog.load();
  final t=c.op('POST','/commands/tasks/create').fields;
  expect(t.map((f)=>f['key']),['title','taskType','description','clientId','packageId','packageProducts']);
  expect(t.where((f)=>f['required']==true).map((f)=>f['key']),['title','description','clientId']);
  expect(c.op('POST','/commands/organization/create-role').fields.map((f)=>f['key']),['name','description']);
  expect(c.op('POST','/commands/departments/create').fields.singleWhere((f)=>f['key']=='Track')['hidden'],true);
  expect(c.op('POST','/public/companies/{slug}/applications').fields.singleWhere((f)=>f['key']=='ReferrerNames')['required'],true);
 });
}
