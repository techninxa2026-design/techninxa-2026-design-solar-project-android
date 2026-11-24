import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcolda/api.dart';
import 'package:idcolda/theme.dart';
import 'package:idcolda/tide_actions.dart';

class LogoApi extends Api {
  String? requested;
  bool? authenticated;
  @override Future<Uint8List> bytes(String path,{bool auth=true}) async{
    requested=path;authenticated=auth;
    return Uint8List(0);
  }
}
void main(){
  testWidgets('Company logo uses authenticated image endpoint with correct company ID',(tester)async{
    final api=LogoApi();addTearDown(api.dispose);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:CompanyIdentityCard(api:api,data:const {
      'id':42,'name':'Solar Partner','slug':'solar-partner',
      'companyKind':'DemandAggregator','logoUrl':'/api/v1/companies/42/logo','active':false
    }))));
    await tester.pumpAndSettle();
    expect(api.requested,'/companies/42/logo');
    expect(api.authenticated,true);
    expect(find.text('Solar Partner'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('Action dock keeps secondary operations in an explicit sheet',(tester)async{
    var tapped='';
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:TideActionDock(actions:[
      TideAction(title:'Open workspace',icon:Icons.business_outlined,onTap:()=>tapped='open'),
      TideAction(title:'Edit branding',icon:Icons.edit_outlined,onTap:()=>tapped='edit'),
      TideAction(title:'Delete company',icon:Icons.delete_outline,onTap:()=>tapped='delete',destructive:true),
    ]))));
    expect(find.text('Edit branding'),findsNothing);
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    expect(find.text('Edit branding'),findsOneWidget);
    expect(find.text('Delete company'),findsOneWidget);
    await tester.ensureVisible(find.text('Edit branding'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit branding'));
    await tester.pumpAndSettle();
    expect(tapped,'edit');
    expect(tester.takeException(),isNull);
  });
}
