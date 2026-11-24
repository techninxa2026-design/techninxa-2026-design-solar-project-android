import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcolda/operations.dart';
import 'package:idcolda/theme.dart';
import 'package:idcolda/tide_editorial.dart';

void main(){
 for(final dark in [false,true]){
  testWidgets('Editorial layouts render actual record data ($dark)',(tester)async{
    tester.view.physicalSize=const Size(360,800);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme:tide(const Brand(),dark),home:Scaffold(body:SingleChildScrollView(child:Column(children:const [
      TideBanner(eyebrow:'WORKSPACE',title:'Inventory',subtitle:'Product catalog',icon:Icons.inventory_2_outlined),
      BusinessRecordCard(module:'clients',section:'items',data:{'name':'Sample client','mobile':'012345','address':'Sample address'}),
      BusinessRecordCard(module:'stock',section:'inventory',data:{'productName':'Solar panel','onHand':17,'unit':'piece'}),
      BusinessRecordCard(module:'dispatches',section:'items',data:{'taskTitle':'Installation','status':'Accepted','scheduledInstallationDate':'2026-11-27'}),
      DetailPanel(data:{'name':'Sample record','password':'not-visible','email':'test@example.invalid'}),
      TideTimelineEntry(title:'Actual work note',description:'Installed equipment',last:true),
      TideNotice('Request failed',error:true),
    ])))));
    await tester.pumpAndSettle();
    expect(find.text('17'),findsOneWidget);
    expect(find.text('Actual work note'),findsOneWidget);
    expect(find.text('not-visible'),findsNothing);
    expect(tester.takeException(),isNull);
  });
 }
}
