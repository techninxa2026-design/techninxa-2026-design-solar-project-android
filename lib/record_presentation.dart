import 'package:flutter/material.dart';
import 'api.dart';
import 'copy.dart';
import 'tide_interactions.dart';
import 'accessibility_catalog.dart';

/// Resolve display names without modifying the API record or its wire IDs.
String displayRole(dynamic code,Map<String,dynamic> source,{dynamic name}){
 if(name!=null&&name.toString().trim().isNotEmpty&&!name.toString().startsWith('OPS_'))return name.toString();
 if(code==null||code.toString().isEmpty)return 'No role assigned';
 final roles=rows(source['roles']);
 final found=roles.where((r)=>r['code']==code).firstOrNull;
 return found?['name']?.toString()??'Role unavailable';
}
String displayPower(dynamic code,Map<String,dynamic> source){
 final all=[...rows(source['availablePowers']),...rows(source['effectivePowers']),...rows(source['navigation'])];
 final match=all.where((x)=>x['code']==code).firstOrNull;
 return accessName(code?.toString()??'',serverLabel:(match?['label']??match?['title'])?.toString());
}
Map<String,dynamic> displayRecord(Map<String,dynamic> record,Map<String,dynamic> source){
 final out={...record};
 if(record['roleCode']!=null){out['roleName']=displayRole(record['roleCode'],source,name:record['roleName']);out.remove('roleCode');}
 if(record['requestedRoleCode']!=null){out['requestedDesignation']=displayRole(record['requestedRoleCode'],source,name:record['requestedDesignation']);out.remove('requestedRoleCode');}
 if(record['powerCode']!=null){out['accessibility']=displayPower(record['powerCode'],source);out.remove('powerCode');}
 if(record['parentPositionId']!=null){final parent=rows(source['positions']).where((p)=>p['id']==record['parentPositionId']).firstOrNull;
 if(parent!=null)out['reportsTo']=displayRole(parent['roleCode'],source);}
 for(final pair in const {'zoneId':'zones','districtId':'districts','areaId':'areas','branchId':'branches','departmentId':'departments','userId':'people'}.entries){
  final id=record[pair.key];if(id==null)continue;
  final candidates=[...rows(source[pair.value]),...rows(obj(source['territory'])[pair.value]),if(pair.key=='userId')...rows(source['users'])];
  final item=candidates.where((x)=>x['id']==id).firstOrNull;
  if(item!=null){final name=item['name']??item['fullName'];if(name!=null){out[pair.key.replaceFirst('Id','Name')]=name;out.remove(pair.key);}}
 }
 return out;
}
bool internalDisplayField(String key)=>const {'id','rolecode','requestedrolecode','powercode','code','expectedupdatedutc','updatedutc','sortorder','createdbyuserid','assignedbyuserid','grantedbyuserid','parentgrantid','membershipid','parentpositionid','parentdepartmentid','companyid','userid','memberid','departmentid','zoneid','districtid','areaid','branchid','productid','packageid','packagenameid','bessid','inverterid','taskid','warehouseid','inventoryid','authoruserid','createduserid','installercompanyid','dacompanyid','track','level'}.contains(key.toLowerCase().replaceAll(' ',''));
class BrandColorPreview extends StatelessWidget{
 final String value;final String title;const BrandColorPreview({super.key,required this.value,required this.title});
 @override Widget build(BuildContext c){
  final color=tideParseColor(value);
  if(color==null)return const CopyText('Color not configured');
  final ink=color.computeLuminance()>.179?Colors.black:Colors.white;
  return Semantics(label:title,child:Container(key:ValueKey('brand-color-'+title),width:double.infinity,padding:const EdgeInsets.all(16),
   decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(16),border:Border.all(color:Theme.of(c).colorScheme.outline)),
   child:Row(children:[Icon(Icons.palette_outlined,color:ink),const SizedBox(width:10),Expanded(child:CopyText(title,style:TextStyle(color:ink,fontWeight:FontWeight.w700)))])));
 }
}
