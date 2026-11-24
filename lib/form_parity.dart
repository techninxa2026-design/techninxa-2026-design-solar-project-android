/// Wire rules from MVC _OpsScope and solar.js.
bool singleTerritoryForm(String path)=>const {
 '/commands/departments/create','/commands/organization/create-role-user',
 '/commands/organization/assign-role','/commands/organization/add-scope',
 '/commands/organization/update-scope','/commands/organization/grant-power',
 '/commands/organization/update-power-grant'
}.contains(path);
void normalizeTerritoryPayload(String path,Map<String,dynamic> data){
 const levels=['zoneid','districtid','areaid','branchid'];
 if(singleTerritoryForm(path)){
  final selected=levels.where((level)=>data.entries.any((e)=>e.key.toLowerCase()==level&&e.value!=null&&e.value.toString().isNotEmpty)).lastOrNull;
  data.removeWhere((key,value)=>levels.contains(key.toLowerCase())&&key.toLowerCase()!=selected);
 }else if(path=='/commands/inventory/create-warehouse'&&data.entries.any((e)=>e.key.toLowerCase()=='branchid'&&e.value!=null&&e.value.toString().isNotEmpty)){
  data.removeWhere((key,_)=>key.toLowerCase()=='areaid');
 }
}
String effectiveTaskStatus(Map<String,dynamic> record,Iterable<dynamic> completedIds)=>
 completedIds.contains(record['id'])?'Completed':record['status']?.toString()??'';
