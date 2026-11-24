import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcolda/api.dart';
import 'package:idcolda/record_presentation.dart';
import 'package:idcolda/workspace_search.dart';
import 'package:idcolda/hierarchy_board.dart';

const manager={'id':1,'roleCode':'OPS_MANAGER','updatedUtc':'2026-11-24T09:00:00Z'};
const worker={'id':2,'roleCode':'OPS_WORKER','parentPositionId':1,'departmentId':5,'updatedUtc':'2026-11-24T09:00:00Z'};
const source={'roles':[{'code':'OPS_MANAGER','name':'Area Manager'},{'code':'OPS_WORKER','name':'Field Engineer'}],'positions':[manager,worker],'departments':[{'id':5,'name':'Sales'},{'id':6,'name':'Technical'}]};
void main(){
 test('Render names without modifying wire identifiers',(){
  final data=displayRecord(worker,source);
  expect(data['roleName'],'Field Engineer');expect(data.containsKey('roleCode'),false);
  expect(worker['roleCode'],'OPS_WORKER');expect(displayRole('OPS_UNKNOWN',source),'Role unavailable');
 });
 test('Search uses only authorized MVC navigation titles',(){
  final api=Api();addTearDown(api.dispose);
  api.me={'accountStatus':'Approved','workspace':{'id':2,'companyKind':'DemandAggregator'},'effectivePowers':['role.create'],'navigation':[{'code':'role.create','title':'Create Roles','group':'ORGANIZATION'},{'code':'people.assign','title':'Manage Team Members','group':'ORGANIZATION'}]};
  final pages=workspaceDestinations(api);
  expect(matchPages(pages,'roles').single.title,'Create Roles');
  expect(matchPages(pages,'Manage Team'),isEmpty);
  expect(matchPages(List.generate(25,(i)=>WorkspaceDestination('Page '+i.toString(),'roles','A')),'').length,20);
 });
 test('Hierarchy drag changes preserve revisions and reject cycles',(){
  expect(hierarchyChange(source,const HierarchyDrag('position',manager),'position',worker),isNull);
  final move=hierarchyChange(source,const HierarchyDrag('position',worker),'root-position',null)!;
  expect(move.action,'move-position');expect(move.payload['parentId'],'');expect(move.payload['expectedUpdatedUtc'],worker['updatedUtc']);
  final assign=hierarchyChange(source,const HierarchyDrag('person',{'id':9,'fullName':'Employee'}),'position',worker)!;
  expect(assign.payload['userId'],9);expect(assign.payload['id'],2);
  final role=hierarchyChange(source,const HierarchyDrag('role',{'code':'OPS_MANAGER','name':'Area Manager'}),'position',worker)!;
  expect(role.action,'change-position-role');expect(role.payload['roleCode'],'OPS_MANAGER');
  final transfer=hierarchyChange(source,const HierarchyDrag('position',worker),'department',{'id':6,'name':'Technical'})!;
  expect(transfer.payload['departmentId'],6);expect(transfer.payload['parentId'],1);
  final moveDept=hierarchyChange(source,const HierarchyDrag('department',{'id':5,'name':'Sales'}),'department',{'id':6,'name':'Technical'})!;
  expect(moveDept.action,'move-department');
 });
 testWidgets('Brand color displays its actual fill rather than hex text',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:BrandColorPreview(value:'#16A9CF',title:'Accent color'))));
  expect(find.text('#16A9CF'),findsNothing);
  final box=tester.widget<Container>(find.byKey(const ValueKey('brand-color-Accent color')));
  expect((box.decoration as BoxDecoration).color,const Color(0xff16a9cf));
 });
 testWidgets('Reporting board fits a narrow phone and supports long-press drag',(tester)async{
  tester.view.physicalSize=const Size(360,740);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:HierarchyBoard(data:source,busy:false,onChange:(_){},onEdit:(_,__){},onCreate:(){}))));
  await tester.pumpAndSettle();
  expect(find.text('Area Manager'),findsWidgets);
  expect(find.byType(LongPressDraggable<HierarchyDrag>),findsWidgets);
  expect(find.byType(InteractiveViewer),findsOneWidget);
  await tester.tap(find.text('List view'));await tester.pumpAndSettle();
  expect(find.text('Reports to'),findsWidgets);
  await tester.tap(find.text('Visual editor'));await tester.pumpAndSettle();
  expect(find.byType(InteractiveViewer),findsOneWidget);
  expect(tester.takeException(),isNull);
 });
}
