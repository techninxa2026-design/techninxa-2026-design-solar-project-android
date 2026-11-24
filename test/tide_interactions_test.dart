import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcolda/tide_interactions.dart';
import 'package:idcolda/theme.dart';

void main(){
 test('Map addresses are URL encoded and saved links are restricted',(){
  final u=tideMapUri(address:'House 5, ঢাকা & Road 7')!;
  expect(u.host,'www.google.com');
  expect(u.queryParameters['query'],'House 5, ঢাকা & Road 7');
  expect(tideMapUri(gps:'https://maps.app.goo.gl/abc')?.host,'maps.app.goo.gl');
  expect(tideMapUri(gps:'https://www.google.com.evil.test/maps/a'),isNull);
  expect(tideMapUri(gps:'javascript:alert(1)'),isNull);
  expect(tideMapUri(gps:'https://evil.test',address:'Dhaka')?.host,'www.google.com');
 });
 test('Color serialization preserves MVC format',(){
  expect(tideColorHex(const Color(0xff087eb1)),'#087EB1');
  expect(tideParseColor('#087EB1')?.toARGB32(),0xff087eb1);
  expect(tideParseColor('blue'),isNull);
 });
 testWidgets('Visual picker commits selected color only on apply',(tester)async{
  String value='#087EB1';
  await tester.pumpWidget(MaterialApp(theme:tide(const Brand(),false),home:Scaffold(body:StatefulBuilder(builder:(c,setState)=>TideColorField(label:'Primary color',value:value,required:true,enabled:true,onChanged:(v)=>setState(()=>value=v))))));
  await tester.tap(find.text('Selected color'));await tester.pumpAndSettle();
  final swatch=find.bySemanticsLabel('Color #16A9CF');
  await tester.ensureVisible(swatch);await tester.pumpAndSettle();
  await tester.tap(swatch);await tester.pumpAndSettle();
  expect(value,'#087EB1');
  await tester.ensureVisible(find.text('Use this color'));await tester.pumpAndSettle();
  await tester.tap(find.text('Use this color'));await tester.pumpAndSettle();
  expect(value,'#16A9CF');
  expect(tester.takeException(),isNull);
 });
 testWidgets('Long choices and filters remain readable on narrow display',(tester)async{
  tester.view.physicalSize=const Size(320,700);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:MediaQuery(data:const MediaQueryData(size:Size(320,700),textScaler:TextScaler.linear(1.7)),child:SingleChildScrollView(child:Column(children:[
   const TideChoiceList(values:{'1':'A long organization name with multiple words','2':'Another option'},selected:{'1'},multiple:true),
   TideSegments<String>(segments:const [ButtonSegment(value:'a',label:Text('Awaiting approval')),ButtonSegment(value:'b',label:Text('Completed')),ButtonSegment(value:'c',label:Text('Rejected'))],selected:const {'a'},onSelectionChanged:(_){}),
   const TideMapLink(address:'A long customer location with a full street address'),
  ]))))));
  await tester.pumpAndSettle();
  expect(tester.takeException(),isNull);
 });
}
