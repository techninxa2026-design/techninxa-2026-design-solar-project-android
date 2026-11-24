import 'dart:convert';
import 'package:flutter/services.dart';
import 'api.dart';
String label(String k) {
  const names={'zoneId':'Zone (division)','districtId':'Area (district)','areaId':'Thana','branchId':'Branch','powerCodes':'Accessibility powers','powerCode':'Accessibility power','roleCode':'Role','roleName':'Role','requestedDesignation':'Requested designation','zoneName':'Zone (Division)','districtName':'Area (District)','areaName':'Thana','branchName':'Branch','userName':'Employee','primaryColor':'Primary brand color','accentColor':'Accent color','expectedUpdatedUtc':'Record revision','bessId':'BESS','inverterId':'Inverter type','packageNameId':'Package name','id':'Selected record','gpsLocationUrl':'GPS location link','nidFront':'NID front','nidBack':'NID back','items':'Package products','packageProducts':'Task product quantities','companyKind':'Company type','sku':'SKU','upc':'UPC','whatsApp':'WhatsApp','whatsapp':'WhatsApp'};
  final s=k.replaceFirst(RegExp(r'^Form\.'),'');final key=s.isEmpty?s:s[0].toLowerCase()+s.substring(1);
  if(names.containsKey(key))return names[key]!;
  return s.replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'),(m)=>'${m[1]} ${m[2]}').replaceAll('-',' ').split(' ').where((x)=>x.isNotEmpty).map((x)=>x[0].toUpperCase()+x.substring(1)).join(' ');
}
class Operation {
  final Map<String,dynamic> raw;
  Operation(this.raw);
  String get method=>raw['method'];String get path=>raw['path'];String get group=>raw['group'];String get mode=>raw['mode'];bool get isPublic=>raw['public']==true;
  List<Map<String,dynamic>> get fields=>rows(raw['fields']);
  String get action=>path.split('/').last;
  String get title=>label(action.replaceAll(RegExp(r'[{}]'),''));
  bool get destructive=>method=='DELETE'||RegExp(r'(delete|remove|revoke|unlink|unassign|clear-read|set-company-admin|logout-all|set-active)').hasMatch(action);
  bool get binary=>method=='GET'&&(path.endsWith('/logo')||path.endsWith('/image')||path.contains('/photo/')||path.endsWith('import-template'));
}
class Catalog {
  final List<Operation> operations;
  Catalog(this.operations);
  static Future<Catalog> load() async=>Catalog(rows(jsonDecode(await rootBundle.loadString('assets/routes.json'))).map(Operation.new).toList());
  Operation op(String method,String path)=>operations.firstWhere((o)=>o.method==method&&o.path==path);
  List<Operation> commands(String group)=>operations.where((o)=>o.group==group&&o.path.startsWith('/commands/')).toList();
}
class Module {
  final String key,title,description,path;
  final List<String> powers;
  const Module(this.key,this.title,this.description,this.path,this.powers);
}
const modules=[
 Module('companies','Company workspaces','Demand Aggregators & Installers','/companies',[]),
 Module('roles','Roles','Define company designations','/organization',['role.create']),
 Module('people','Team members','Manage roles, scope and accessibility','/organization',['people.assign']),
 Module('accounts','Create accounts','Initial accounts & application links','/departments',['account.create']),
 Module('applications','Application forms','Review and route applications','/departments/applications',['account.create']),
 Module('departments','Departments','Manage teams and assignments','/departments',['department.create']),
 Module('hierarchy','Organization hierarchy','Reporting & approval structure','/hierarchy',['hierarchy.manage']),
 Module('territories','Territories','Division · district · thana · branch','/organization',['zone.create','district.assign','area.create','branch.create']),
 Module('warehouses','Warehouses','Manage warehouse locations','/inventory',['warehouse.create']),
 Module('products','Products','Catalog, images and datasheets','/inventory',['product.create']),
 Module('stock','Stock','Assign products and adjust stock','/inventory',['stock.assign','store.manage']),
 Module('clients','Client portal','Active and archived clients','/clients',['client.create']),
 Module('packages','Solar packages','Parameters, products and packages','/packages',['package.manage']),
 Module('tasks','Tasks','Create, assign, monitor and report','/tasks',['task.create','task.assign','task.monitor.assign','task.report']),
 Module('dispatches','Installer assignments','Schedule, progress and completion','/dispatches',['task.assign','task.create','task.report']),
 Module('sales','Sales records','Verified installation records','/sales',[]),
 Module('notifications','Notifications','Account and task activity','/notifications',[]),
 Module('profile','My profile','Personal details and security','/profile',[]),
];
bool visible(Module m,Api a){
 if(m.key=='companies')return a.superAdmin;
 if(m.key=='notifications'||m.key=='profile')return true;
 if(!a.approved)return false;
 if(m.key=='sales')return a.me['canViewSales']==true;
 if(a.me['workspace']==null)return false;
 if((m.key=='dispatches'||m.key=='tasks')&&a.me['hasAssignedTasks']==true)return true;
 return m.powers.any(a.powers.contains);
}
