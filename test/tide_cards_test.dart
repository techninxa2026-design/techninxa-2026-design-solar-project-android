import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcolda/theme.dart';
import 'package:idcolda/tide_cards.dart';
import 'package:idcolda/operations.dart';

void main(){
  for(final dark in [false,true]){
    testWidgets('Prism cards adapt to narrow screens and large text ($dark)',(tester)async{
      tester.view.physicalSize=const Size(320,700);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var taps=0;
      await tester.pumpWidget(MaterialApp(theme:tide(const Brand(),dark),home:Scaffold(
        body:MediaQuery(data:const MediaQueryData(size:Size(320,700),textScaler:TextScaler.linear(1.8)),child:
          ListView(padding:const EdgeInsets.all(16),children:[
            const TideGrid(children:[
              TideMetric(label:'Active members',value:'1234',icon:Icons.groups_outlined),
              TideMetric(label:'Sales this month',value:'৳ 105000.00',icon:Icons.payments_outlined),
            ]),
            BusinessRecordCard(module:'dispatches',section:'items',data:const {
              'taskTitle':'Solar installation with a long project title','status':'Pending',
              'daOfferedInstallationDate':'2026-11-28','customerMobile':null,
            },onTap:()=>taps++),
            const DetailPanel(data:{'name':'Test customer','address':'A long address that should wrap without overflow at a large text scale.','password':'do-not-show'}),
          ])),
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      await tester.scrollUntilVisible(find.text('Solar installation with a long project title'),150,scrollable:find.byType(Scrollable).first);
      await tester.tap(find.text('Solar installation with a long project title'));
      await tester.pumpAndSettle();
      expect(taps,1);
      expect(find.text('do-not-show'),findsNothing);
      expect(tester.takeException(),isNull);
    });
  }
}
