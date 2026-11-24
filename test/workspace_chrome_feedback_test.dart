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
   expect(strip.borderRadius,workspaceBarShape);
   final context=tester.element(find.byType(AppBar));
   expect(Theme.of(context).appBarTheme.backgroundColor,strip.color);
   expect(Theme.of(context).appBarTheme.foregroundColor,Colors.white);
   expect(tester.takeException(),isNull);
  }
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
