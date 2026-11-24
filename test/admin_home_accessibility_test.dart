import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcolda/accessibility_catalog.dart';
import 'package:idcolda/admin_home.dart';
import 'package:idcolda/api.dart';
import 'package:idcolda/theme.dart';
import 'package:idcolda/workspace_search.dart';

class AdminFixture extends Api{
 @override Future<dynamic> get(String path,{Map<String,dynamic> query=const{},bool auth=true}) async=>{'items':[{'id':1,'name':'Solar Network','companyKind':'DemandAggregator','active':true},{'id':2,'name':'Installation Partner','companyKind':'Installer','active':false}],'memberCounts':{'1':3,'2':2}};
}
void main(){
 test('MVC permission catalog includes 19 exact keys with meaningful labels',(){
  expect(accessFeatures.length,19);
  expect(accessName('task.create',serverLabel:'task.create'),'Create written tasks');
  expect(accessName('stock.assign'),'Assign products to warehouses');
  expect(accessName('unknown.code'),isNot('unknown.code'));
  expect(accessGroup('hierarchy.manage'),'Organization & Accounts');
 });
 testWidgets('Checklist returns original granted codes, never additional catalog permissions',(tester)async{
  Set<String>? saved;
  await tester.pumpWidget(MaterialApp(home:Builder(builder:(c)=>Scaffold(body:TextButton(onPressed:()async{saved=await Navigator.push<Set<String>>(c,MaterialPageRoute(builder:(_)=>const Scaffold(body:SingleChildScrollView(child:AccessibilityChecklist(choices:{'task.create':'task.create','task.report':'Submit monitoring reports'},selected:{})))));},child:const Text('Open checklist'))))));
  await tester.tap(find.text('Open checklist'));await tester.pumpAndSettle();
  expect(find.text('task.create'),findsNothing);
  expect(find.text('Create written tasks'),findsOneWidget);
  expect(find.byKey(const ValueKey('access-role.create')),findsNothing);
  await tester.ensureVisible(find.byKey(const ValueKey('access-task.create')));await tester.tap(find.byKey(const ValueKey('access-task.create')));await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Apply selection').first);await tester.tap(find.text('Apply selection').first);await tester.pumpAndSettle();
  expect(saved,{'task.create'});
 });
 test('Admin feature search contains company actions and no unscoped company operation',(){
  final api=Api();addTearDown(api.dispose);api.me={'isSuperAdmin':true,'accountStatus':'Approved','effectivePowers':['task.create']};
  final pages=workspaceDestinations(api);
  expect(pages.any((p)=>p.module=='register-company'),true);
  expect(pages.any((p)=>p.module=='choose-workspace'),true);
  expect(pages.any((p)=>p.module=='tasks'),false);
 });
 testWidgets('Admin landing page displays live fixture counts and fits 320px',(tester)async{
  tester.view.physicalSize=const Size(320,720);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final api=AdminFixture();addTearDown(api.dispose);api.me={'fullName':'Platform administrator'};
  Future<void> noop()async{}
  await tester.pumpWidget(MaterialApp(theme:tide(const Brand(),false),home:Scaffold(body:AdminHome(api:api,brand:const Brand(),unread:0,openCompanies:noop,openNotifications:noop,register:noop,choose:noop,openCompany:(_,__)async{}))));
  await tester.pumpAndSettle();
  expect(find.text('Registered companies'),findsOneWidget);expect(find.text('2'),findsOneWidget);
  expect(tester.takeException(),isNull);
  await tester.scrollUntilVisible(find.text('Register company'),180);await tester.pumpAndSettle();expect(tester.takeException(),isNull);
 });
 testWidgets('Search bar uses requested feature wording',(tester)async{
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:FeatureSearchBar(onTap:(){}))));
  expect(find.text('Find a feature'),findsOneWidget);expect(find.text('Find a page'),findsNothing);
 });
}
