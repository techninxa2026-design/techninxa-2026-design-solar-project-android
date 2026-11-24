import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcolda/workspace_chrome.dart';
import 'package:idcolda/feedback.dart';
import 'package:idcolda/theme.dart';
import 'package:idcolda/hierarchy_board.dart';

void main(){
 testWidgets('Branded feedback has meaningful title and can be dismissed',(tester)async{
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(c)=>TextButton(onPressed:()=>showFeedback('Record saved',context:c,kind:FeedbackKind.success),child:const Text('Save'))))));
  await tester.tap(find.text('Save'));await tester.pumpAndSettle();
  expect(find.text('Successful'),findsOneWidget);expect(find.text('Record saved'),findsOneWidget);
  await tester.tap(find.byTooltip('Dismiss message'));await tester.pumpAndSettle();
  expect(find.text('Record saved'),findsNothing);
 });
 testWidgets('New home chrome fits a narrow display and preserves destinations',(tester)async{
  tester.view.physicalSize=const Size(320,700);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  String? chosen;
  await tester.pumpWidget(MaterialApp(home:Scaffold(appBar:WorkspaceHeader(logo:const Icon(Icons.sunny,size:44),title:'A long company workspace name',subtitle:'Company workspace',unread:4,approved:true,onNotifications:(){},onAccount:(){},onSearch:(){}),body:const SizedBox(),bottomNavigationBar:WorkspaceNavigation(items:const [WorkspaceNavItem('home','Home',Icons.home),WorkspaceNavItem('tasks','Tasks',Icons.task),WorkspaceNavItem('stores','Stores',Icons.store),WorkspaceNavItem('modules','Modules',Icons.apps),WorkspaceNavItem('account','Account',Icons.person)],selected:'home',onSelect:(x)=>chosen=x))));
  await tester.tap(find.byKey(const ValueKey('nav-tasks')));await tester.pumpAndSettle();expect(chosen,'tasks');expect(find.text('Tasks'),findsNothing);expect(find.byTooltip('Tasks'),findsOneWidget);expect(tester.takeException(),isNull);
 });
 testWidgets('Reference strip and standard app bars share the branded color and curvature',(tester)async{
  const brand=Brand();
  for(final dark in [false,true]){
   await tester.pumpWidget(MaterialApp(theme:tide(brand,dark),home:Scaffold(appBar:AppBar(title:const Text('Company details')),body:const SizedBox(),bottomNavigationBar:WorkspaceNavigation(items:const [WorkspaceNavItem('home','Home',Icons.home),WorkspaceNavItem('account','Account',Icons.person)],selected:'home',onSelect:(_){}))));
   await tester.pumpAndSettle();
   final strip=tester.widget<Material>(find.byKey(const ValueKey('workspace-navigation-strip')));
   expect(strip.color,brand.deep);
   expect(strip.borderRadius,workspaceNavShape);
   expect(workspaceNavShape.topLeft,const Radius.circular(26));
   expect(workspaceNavShape.bottomLeft,Radius.zero);
   final context=tester.element(find.byType(AppBar));
   expect(Theme.of(context).appBarTheme.backgroundColor,strip.color);
   expect(Theme.of(context).appBarTheme.foregroundColor,Colors.white);
   expect(tester.takeException(),isNull);
  }
 });
 testWidgets('Bottom bar fills the safe inset with the same blue surface',(tester)async{
  tester.view.physicalSize=const Size(360,740);tester.view.devicePixelRatio=1;
  tester.view.padding=const FakeViewPadding(bottom:24);
  tester.view.viewPadding=const FakeViewPadding(bottom:24);
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);addTearDown(tester.view.resetViewPadding);
  await tester.pumpWidget(MaterialApp(theme:tide(const Brand(),false),home:Scaffold(body:const SizedBox(),bottomNavigationBar:WorkspaceNavigation(items:const [WorkspaceNavItem('home','Home',Icons.home)],selected:'home',onSelect:(_){}))));
  final rect=tester.getRect(find.byKey(const ValueKey('workspace-navigation-strip')));
  expect(rect.bottom,740);expect(rect.height,82);
  expect(tester.getRect(find.byKey(const ValueKey('nav-home'))).bottom,716);
 });
 testWidgets('Hierarchy editor is a broad working sheet, not a detail card',(tester)async{
  tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  const data=<String,dynamic>{'roles':[{'code':'r','name':'Manager'}],'positions':[{'id':1,'roleCode':'r','updatedUtc':'2026-11-24T00:00:00Z'}]};
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(c)=>TextButton(onPressed:()=>showHierarchyEditor(c,data:data,refresh:()async=>data,onChange:(_)async{},onEdit:(_,__,___)async{},onCreate:(_)async{}),child:const Text('Open editor'))))));
  await tester.tap(find.text('Open editor'));await tester.pumpAndSettle();
  final rect=tester.getRect(find.byKey(const ValueKey('hierarchy-editor-sheet')));
  expect(rect.width,390);expect(rect.height,greaterThan(780));
  expect(find.byType(InteractiveViewer),findsOneWidget);
  expect(find.byKey(const ValueKey('drag-position-1')),findsOneWidget);
  expect(find.text('Company (Admin)'),findsOneWidget);
  final viewer=tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
  expect(viewer.transformationController!.value.getMaxScaleOnAxis(),greaterThanOrEqualTo(.85));
  expect(tester.takeException(),isNull);
  await tester.tap(find.byTooltip('Close hierarchy editor'));await tester.pumpAndSettle();
  expect(find.byType(InteractiveViewer),findsNothing);
 });
 testWidgets('Actual drag handle emits the same move as MVC',(tester)async{
  tester.view.physicalSize=const Size(760,1050);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  HierarchyChange? change;
  const data={'companyAdministrator':'Administrator','roles':[{'code':'r1','name':'Manager'},{'code':'r2','name':'Engineer'}],'positions':[{'id':1,'roleCode':'r1','updatedUtc':'2026-11-24T00:00:00Z'},{'id':2,'roleCode':'r2','updatedUtc':'2026-11-24T00:00:00Z'}]};
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:HierarchyBoard(data:data,busy:false,onChange:(x)=>change=x,onEdit:(_,__){},onCreate:(){}))));
  await tester.pumpAndSettle();
  final from=find.byKey(const ValueKey('drag-position-2'));final to=find.byKey(const ValueKey('node-position-1'));
  expect(from,findsOneWidget);expect(to,findsOneWidget);
  final gesture=await tester.startGesture(tester.getCenter(from));
  await gesture.moveBy(const Offset(0,22));await tester.pump();
  await gesture.moveTo(tester.getCenter(to));await tester.pump();await gesture.up();await tester.pumpAndSettle();
  expect(change?.action,'move-position');expect(change?.payload['id'],2);expect(change?.payload['parentId'],1);
  expect(tester.takeException(),isNull);
 });
}
