import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:idcolda/reactive_state.dart';
void main(){
 test('notification requests coalesce and disposal rejects late updates',()async{
  final c=WorkspaceStateController();final wait=Completer<int>();var calls=0;
  final first=c.refreshUnread((){calls++;return wait.future;});
  await c.refreshUnread(()async{calls++;return 9;});
  expect(calls,1);c.release();wait.complete(7);await first;
 });
 testWidgets('badge update does not rebuild static sibling',(tester)async{
  final c=WorkspaceStateController();var staticBuilds=0;
  await tester.pumpWidget(MaterialApp(home:Column(children:[Builder(builder:(_){staticBuilds++;return const Text('Static');}),Obx(()=>Text(c.unread.value.toString()))])));
  await c.refreshUnread(()async=>3);await tester.pump();
  expect(find.text('3'),findsOneWidget);expect(staticBuilds,1);
  await tester.pumpWidget(const SizedBox());c.release();
 });
 testWidgets('resource refresh ignores late previous completion',(tester)async{
  final first=Completer<String>(),second=Completer<String>();var calls=0;
  final resource=ReactiveResource<String>(()=>calls++==0?first.future:second.future);
  await tester.pumpWidget(MaterialApp(home:ReactiveResourceBuilder<String>(resource:resource,builder:(_,s)=>Text(s.data??'Loading'))));
  final next=resource.reload();second.complete('New');await next;await tester.pump();await tester.pump();
  first.complete('Old');await tester.pump();expect(find.text('New'),findsOneWidget);
  await tester.pumpWidget(const SizedBox());resource.release();
 });
}
